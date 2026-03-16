"""Messaging service: resolve recipients and create notifications per user."""
from uuid import UUID
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.branch import BranchAssignment
from app.models.student import Student
from app.models.notification import Notification
from app.models.student import ParentStudentLink
from app.services.notification_service import send_onesignal_notification


def _staff_roles() -> list[str]:
    return ["admin", "coordinator", "teacher", "bus_staff"]


def get_admin_recipients(
    db: Session,
    target_type: str,
    branch_id: UUID | None = None,
    class_id: UUID | None = None,
) -> list[UUID]:
    """Resolve recipient user IDs for admin send."""
    user_ids: set[UUID] = set()

    if target_type == "all_staff":
        users = db.query(User).filter(User.role.in_(_staff_roles()), User.is_active == "true").all()
        user_ids.update(u.id for u in users)

    elif target_type == "all_parents":
        users = db.query(User).filter(User.role == "parent", User.is_active == "true").all()
        user_ids.update(u.id for u in users)

    elif target_type == "all":
        users = db.query(User).filter(User.is_active == "true").all()
        user_ids.update(u.id for u in users)

    elif target_type == "branch_staff" and branch_id:
        assignments = db.query(BranchAssignment).filter(BranchAssignment.branch_id == branch_id).all()
        for a in assignments:
            u = db.query(User).filter(User.id == a.user_id, User.is_active == "true").first()
            if u and u.role in _staff_roles():
                user_ids.add(u.id)

    elif target_type == "branch_parents" and branch_id:
        students = db.query(Student).filter(Student.branch_id == branch_id).all()
        student_ids = [s.id for s in students]
        links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id.in_(student_ids)).all()
        for link in links:
            u = db.query(User).filter(User.id == link.user_id, User.is_active == "true").first()
            if u:
                user_ids.add(u.id)

    elif target_type == "branch_all" and branch_id:
        # Staff in branch
        assignments = db.query(BranchAssignment).filter(BranchAssignment.branch_id == branch_id).all()
        for a in assignments:
            u = db.query(User).filter(User.id == a.user_id, User.is_active == "true").first()
            if u and u.role in _staff_roles():
                user_ids.add(u.id)
        # Parents with students in branch
        students = db.query(Student).filter(Student.branch_id == branch_id).all()
        student_ids = [s.id for s in students]
        links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id.in_(student_ids)).all()
        for link in links:
            u = db.query(User).filter(User.id == link.user_id, User.is_active == "true").first()
            if u:
                user_ids.add(u.id)

    elif target_type == "grade_teachers" and class_id:
        assignments = db.query(BranchAssignment).filter(
            BranchAssignment.class_id == class_id,
        ).all()
        for a in assignments:
            u = db.query(User).filter(User.id == a.user_id, User.is_active == "true").first()
            if u and u.role == "teacher":
                user_ids.add(u.id)

    return list(user_ids)


def get_coordinator_recipients(
    db: Session,
    coordinator_branch_id: UUID,
    target_type: str,
) -> list[UUID]:
    """Resolve recipient user IDs for coordinator send."""
    user_ids: set[UUID] = set()

    if target_type == "branch_teachers":
        assignments = db.query(BranchAssignment).filter(
            BranchAssignment.branch_id == coordinator_branch_id,
            BranchAssignment.class_id.isnot(None),
        ).all()
        for a in assignments:
            u = db.query(User).filter(User.id == a.user_id, User.is_active == "true").first()
            if u and u.role == "teacher":
                user_ids.add(u.id)

    elif target_type == "branch_parents":
        students = db.query(Student).filter(Student.branch_id == coordinator_branch_id).all()
        student_ids = [s.id for s in students]
        links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id.in_(student_ids)).all()
        for link in links:
            u = db.query(User).filter(User.id == link.user_id, User.is_active == "true").first()
            if u:
                user_ids.add(u.id)

    return list(user_ids)


def get_parent_recipients(
    db: Session,
    parent_user_id: UUID,
) -> tuple[list[UUID], str | None]:
    """Resolve recipient user IDs for parent send: teachers of their child's grade(s).
    Returns (user_ids, error_message). error_message is set when no recipients found."""
    user_ids: set[UUID] = set()
    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == parent_user_id).all()
    if not links:
        return [], "No child linked to your account. Contact admin to link your child."
    students_with_class = 0
    for link in links:
        student = db.query(Student).filter(Student.id == link.student_id).first()
        if not student:
            continue
        if not student.class_id:
            continue
        students_with_class += 1
        assignments = db.query(BranchAssignment).filter(
            BranchAssignment.class_id == student.class_id,
        ).all()
        for a in assignments:
            u = db.query(User).filter(User.id == a.user_id, User.is_active == "true").first()
            if u and u.role == "teacher":
                user_ids.add(u.id)
    if not user_ids:
        if students_with_class == 0:
            return [], "Your child has no grade/class assigned. Contact admin."
        return [], "No teachers assigned to your child's grade yet. Contact admin."
    return list(user_ids), None


def create_notifications_for_users(
    db: Session,
    recipient_ids: list[UUID],
    title: str,
    message: str,
    sender_id: UUID | None = None,
) -> int:
    """Create one notification per recipient and send push if they have OneSignal ID."""
    count = 0
    subscription_ids: list[str] = []
    for uid in recipient_ids:
        n = Notification(
            user_id=uid,
            sender_id=sender_id,
            title=title,
            message=message,
        )
        db.add(n)
        count += 1
        user = db.query(User).filter(User.id == uid).first()
        if user and user.onesignal_player_id:
            subscription_ids.append(user.onesignal_player_id)
    db.commit()
    if subscription_ids:
        send_onesignal_notification(subscription_ids, title, message)
    return count
