"""Leave applications: parent submits, staff reviews.

Security:
- Parent may submit/list only for students linked to them (ParentStudentLink).
- Staff scope:
    admin       -> all leaves
    coordinator -> leaves for students in coordinator's branch
    teacher     -> leaves for students in teacher's class
- Only staff with authority over the subject student may approve/reject.
"""
from datetime import date, datetime, timezone
from uuid import UUID
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import get_current_user
from app.models.user import User
from app.models.student import Student, ParentStudentLink
from app.models.branch import BranchAssignment
from app.models.leave import LeaveApplication
from app.services.notification_service import send_onesignal_notification

router = APIRouter(prefix="/leave", tags=["leave"])

MAX_REASON = 500
MAX_NOTE = 500


class CreateLeaveRequest(BaseModel):
    student_id: UUID
    reason: str = Field(..., min_length=1, max_length=MAX_REASON)
    start_date: date
    end_date: date

    @field_validator("reason")
    @classmethod
    def strip_reason(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Reason cannot be empty")
        return v


class ReviewLeaveRequest(BaseModel):
    status: str  # approved | rejected
    note: Optional[str] = Field(None, max_length=MAX_NOTE)

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        v = (v or "").lower().strip()
        if v not in ("approved", "rejected"):
            raise ValueError("status must be 'approved' or 'rejected'")
        return v


def _is_staff(user: User) -> bool:
    return user.role in ("admin", "coordinator", "teacher")


def _staff_scope_student_ids(db: Session, staff: User) -> Optional[set[UUID]]:
    """None = no restriction (admin). Set = restricted list."""
    if staff.role == "admin":
        return None
    if staff.role == "coordinator":
        a = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == staff.id,
            BranchAssignment.class_id.is_(None),
        ).first()
        if not a:
            return set()
        ids = db.query(Student.id).filter(Student.branch_id == a.branch_id).all()
        return {i[0] for i in ids}
    if staff.role == "teacher":
        a = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == staff.id,
            BranchAssignment.class_id.isnot(None),
        ).first()
        if not a:
            return set()
        ids = db.query(Student.id).filter(Student.class_id == a.class_id).all()
        return {i[0] for i in ids}
    return set()


def _serialize(app: LeaveApplication, student: Optional[Student], parent: Optional[User], reviewer: Optional[User]) -> dict:
    return {
        "id": str(app.id),
        "student_id": str(app.student_id),
        "student_name": student.name if student else None,
        "student_admission_number": student.admission_number if student else None,
        "parent_user_id": str(app.parent_user_id),
        "parent_name": parent.full_name if parent else None,
        "parent_phone": parent.phone if parent else None,
        "reason": app.reason,
        "start_date": app.start_date.isoformat() if app.start_date else None,
        "end_date": app.end_date.isoformat() if app.end_date else None,
        "status": app.status,
        "reviewed_by": str(app.reviewed_by) if app.reviewed_by else None,
        "reviewer_name": reviewer.full_name if reviewer else None,
        "reviewed_at": app.reviewed_at.isoformat() if app.reviewed_at else None,
        "review_note": app.review_note,
        "created_at": app.created_at.isoformat() if app.created_at else None,
    }


def _hydrate(db: Session, app: LeaveApplication) -> dict:
    student = db.query(Student).filter(Student.id == app.student_id).first()
    parent = db.query(User).filter(User.id == app.parent_user_id).first()
    reviewer = db.query(User).filter(User.id == app.reviewed_by).first() if app.reviewed_by else None
    return _serialize(app, student, parent, reviewer)


@router.post("")
def create_leave(
    data: CreateLeaveRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents may submit leave")
    if data.end_date < data.start_date:
        raise HTTPException(status_code=400, detail="end_date must be on/after start_date")

    link = db.query(ParentStudentLink).filter(
        ParentStudentLink.user_id == user.id,
        ParentStudentLink.student_id == data.student_id,
    ).first()
    if not link:
        raise HTTPException(status_code=403, detail="Student is not linked to your account")

    app = LeaveApplication(
        student_id=data.student_id,
        parent_user_id=user.id,
        reason=data.reason,
        start_date=data.start_date,
        end_date=data.end_date,
        status="pending",
    )
    db.add(app)
    db.commit()
    db.refresh(app)

    # Push to eligible staff (teacher of class + coordinator of branch + admins).
    student = db.query(Student).filter(Student.id == app.student_id).first()
    if student:
        recipient_sids: set[str] = set()
        staff_ids: set[UUID] = set()
        if student.class_id:
            ta = db.query(BranchAssignment).filter(BranchAssignment.class_id == student.class_id).all()
            staff_ids.update(a.user_id for a in ta)
        if student.branch_id:
            ca = db.query(BranchAssignment).filter(
                BranchAssignment.branch_id == student.branch_id,
                BranchAssignment.class_id.is_(None),
            ).all()
            staff_ids.update(a.user_id for a in ca)
        admins = db.query(User).filter(User.role == "admin", User.is_active == "true").all()
        staff_ids.update(a.id for a in admins)
        if staff_ids:
            recipients = db.query(User).filter(User.id.in_(staff_ids)).all()
            for r in recipients:
                sid = (r.onesignal_player_id or "").strip() if r.onesignal_player_id else ""
                if sid:
                    recipient_sids.add(sid)
        if recipient_sids:
            title = "New leave request"
            body = f"{user.full_name or 'Parent'} requested leave for {student.name}"
            try:
                send_onesignal_notification(list(recipient_sids), title, body)
            except Exception:
                pass

    return _hydrate(db, app)


@router.get("")
def list_leaves(
    status: Optional[str] = Query(None),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    q = db.query(LeaveApplication)

    if user.role == "parent":
        q = q.filter(LeaveApplication.parent_user_id == user.id)
    elif _is_staff(user):
        scope = _staff_scope_student_ids(db, user)
        if scope is not None:
            if not scope:
                return []
            q = q.filter(LeaveApplication.student_id.in_(scope))
    else:
        raise HTTPException(status_code=403, detail="Not allowed")

    if status:
        s = status.lower().strip()
        if s not in ("pending", "approved", "rejected"):
            raise HTTPException(status_code=400, detail="invalid status filter")
        q = q.filter(LeaveApplication.status == s)

    items = q.order_by(LeaveApplication.created_at.desc()).all()
    return [_hydrate(db, a) for a in items]


@router.post("/{leave_id}/review")
def review_leave(
    leave_id: UUID,
    data: ReviewLeaveRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not _is_staff(user):
        raise HTTPException(status_code=403, detail="Staff only")

    app = db.query(LeaveApplication).filter(LeaveApplication.id == leave_id).first()
    if not app:
        raise HTTPException(status_code=404, detail="Leave not found")
    if app.status != "pending":
        raise HTTPException(status_code=400, detail="Leave already reviewed")

    scope = _staff_scope_student_ids(db, user)
    if scope is not None and app.student_id not in scope:
        raise HTTPException(status_code=403, detail="Not allowed for this student")

    app.status = data.status
    app.reviewed_by = user.id
    app.reviewed_at = datetime.now(timezone.utc)
    app.review_note = (data.note or "").strip() or None
    db.commit()
    db.refresh(app)

    parent = db.query(User).filter(User.id == app.parent_user_id).first()
    student = db.query(Student).filter(Student.id == app.student_id).first()
    if parent and parent.onesignal_player_id:
        sid = (parent.onesignal_player_id or "").strip()
        if sid:
            title = f"Leave {app.status}"
            body = f"Your leave request for {student.name if student else 'your child'} was {app.status}"
            try:
                send_onesignal_notification([sid], title, body)
            except Exception:
                pass

    return _hydrate(db, app)
