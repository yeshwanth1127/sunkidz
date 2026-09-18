from datetime import date
import logging
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.branch import BranchAssignment
from app.models.leave import LeaveApplication
from app.models.student import ParentStudentLink, Student
from app.models.user import User
from app.services.chat_event_service import post_event_message
from app.services.notification_service import send_onesignal_notification

logger = logging.getLogger(__name__)


def _staff_ids_for_student(db: Session, student: Student) -> set[UUID]:
    staff_ids: set[UUID] = set()
    if student.class_id:
        teacher_assignments = db.query(BranchAssignment).filter(
            BranchAssignment.class_id == student.class_id
        ).all()
        staff_ids.update(a.user_id for a in teacher_assignments)
    if student.branch_id:
        coordinator_assignments = db.query(BranchAssignment).filter(
            BranchAssignment.branch_id == student.branch_id,
            BranchAssignment.class_id.is_(None),
        ).all()
        staff_ids.update(a.user_id for a in coordinator_assignments)
    admins = db.query(User).filter(User.role == "admin", User.is_active == "true").all()
    staff_ids.update(admin.id for admin in admins)
    return staff_ids


def create_leave_application(
    db: Session,
    *,
    parent_user: User,
    student_id: UUID,
    reason: str,
    start_date: date,
    end_date: date,
) -> LeaveApplication:
    if parent_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents may submit leave")
    if end_date < start_date:
        raise HTTPException(status_code=400, detail="end_date must be on/after start_date")

    link = db.query(ParentStudentLink).filter(
        ParentStudentLink.user_id == parent_user.id,
        ParentStudentLink.student_id == student_id,
    ).first()
    if not link:
        raise HTTPException(status_code=403, detail="Student is not linked to your account")

    app = LeaveApplication(
        student_id=student_id,
        parent_user_id=parent_user.id,
        reason=reason,
        start_date=start_date,
        end_date=end_date,
        status="pending",
    )
    db.add(app)
    db.commit()
    db.refresh(app)

    student = db.query(Student).filter(Student.id == app.student_id).first()
    if not student:
        return app

    staff_ids = _staff_ids_for_student(db, student)
    recipient_sids: set[str] = set()
    if staff_ids:
        recipients = db.query(User).filter(User.id.in_(staff_ids)).all()
        for recipient in recipients:
            sid = (recipient.onesignal_player_id or "").strip() if recipient.onesignal_player_id else ""
            if sid:
                recipient_sids.add(sid)
    if recipient_sids:
        title = "New leave request"
        body = f"{parent_user.full_name or 'Parent'} requested leave for {student.name}"
        try:
            send_onesignal_notification(list(recipient_sids), title, body)
        except Exception:
            logger.exception("Failed to send leave request push notification")

    event_body = (
        f"[Leave Request] {student.name}: {app.start_date.isoformat()} to {app.end_date.isoformat()}. "
        f"Reason: {app.reason}"
    )
    for staff_id in staff_ids:
        try:
            post_event_message(
                db,
                parent_user_id=parent_user.id,
                staff_user_id=staff_id,
                sender_id=parent_user.id,
                student_id=student.id,
                body=event_body,
                send_push=False,
            )
        except Exception:
            logger.exception(
                "Failed to append leave request event into chat",
                extra={
                    "parent_user_id": str(parent_user.id),
                    "staff_user_id": str(staff_id),
                    "student_id": str(student.id),
                },
            )

    return app
