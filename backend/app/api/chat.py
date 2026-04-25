"""Two-way chat API: threaded messaging between parents and staff.

Security model:
- A thread has exactly two parties: parent_user_id and staff_user_id (optionally scoped to student_id).
- Only the two parties may read or post messages in a thread.
- Staff may initiate a thread only with parents they have authority over:
    admin       -> any parent
    coordinator -> parents of students in the coordinator's assigned branch
    teacher     -> parents of students in the teacher's assigned class
- Parent may initiate a thread only with staff tied to their child:
    any admin, the coordinator of their child's branch, or teachers of their child's class.
- Message body is capped (<= 2000 chars). Rate limit: 30 messages / 60s / user.
"""
from datetime import date, datetime, timedelta, timezone
from uuid import UUID
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import or_, func as sqlfunc
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import get_current_user
from app.models.user import User
from app.models.student import Student, ParentStudentLink
from app.models.branch import BranchAssignment
from app.models.message import MessageThread, Message
from app.services.leave_service import create_leave_application
from app.services.notification_service import send_onesignal_notification

router = APIRouter(prefix="/chat", tags=["chat"])

MAX_BODY = 2000
RATE_LIMIT_COUNT = 30
RATE_LIMIT_WINDOW_SECONDS = 60
EVENT_PREFIXES = (
    "[Leave Request]",
    "[Leave Approved]",
    "[Leave Rejected]",
    "[Marks Card Sent]",
)


# ---------------- Schemas ----------------
class StartThreadRequest(BaseModel):
    other_user_id: UUID
    student_id: Optional[UUID] = None


class SendMessageRequest(BaseModel):
    body: str = Field(..., min_length=1, max_length=MAX_BODY)

    @field_validator("body")
    @classmethod
    def strip_body(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Body cannot be empty")
        return v


class CreateThreadLeaveRequest(BaseModel):
    reason: str = Field(..., min_length=1, max_length=500)
    start_date: date
    end_date: date

    @field_validator("reason")
    @classmethod
    def strip_reason(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("Reason cannot be empty")
        return v


# ---------------- Helpers ----------------
def _is_staff(user: User) -> bool:
    return user.role in ("admin", "coordinator", "teacher")


def _authority_over_student(db: Session, staff: User, student_id: UUID) -> bool:
    """True if this staff member has authority over the given student."""
    if staff.role == "admin":
        return True
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        return False
    if staff.role == "coordinator":
        a = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == staff.id,
            BranchAssignment.class_id.is_(None),
        ).first()
        return bool(a and student.branch_id == a.branch_id)
    if staff.role == "teacher":
        a = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == staff.id,
            BranchAssignment.class_id.isnot(None),
        ).first()
        return bool(a and student.class_id == a.class_id)
    return False


def _staff_can_message_parent(db: Session, staff: User, parent: User, student_id: Optional[UUID]) -> bool:
    """Staff may message a parent only if they share authority over at least one of the parent's children.
    If student_id is provided, authority must be over that specific student AND the parent must be linked to it.
    """
    if parent.role != "parent":
        return False
    if staff.role == "admin":
        if student_id is not None:
            link = db.query(ParentStudentLink).filter(
                ParentStudentLink.user_id == parent.id,
                ParentStudentLink.student_id == student_id,
            ).first()
            return link is not None
        return True

    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == parent.id).all()
    if not links:
        return False
    parent_student_ids = {l.student_id for l in links}
    if student_id is not None:
        if student_id not in parent_student_ids:
            return False
        return _authority_over_student(db, staff, student_id)
    return any(_authority_over_student(db, staff, sid) for sid in parent_student_ids)


def _parent_can_message_staff(db: Session, parent: User, staff: User, student_id: Optional[UUID]) -> bool:
    """Parent may message staff who has authority over (optionally the specified) one of their children."""
    if staff.role not in ("admin", "coordinator", "teacher"):
        return False
    if staff.role == "admin":
        if student_id is not None:
            link = db.query(ParentStudentLink).filter(
                ParentStudentLink.user_id == parent.id,
                ParentStudentLink.student_id == student_id,
            ).first()
            return link is not None
        return True

    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == parent.id).all()
    parent_student_ids = {l.student_id for l in links}
    if not parent_student_ids:
        return False
    if student_id is not None:
        if student_id not in parent_student_ids:
            return False
        return _authority_over_student(db, staff, student_id)
    return any(_authority_over_student(db, staff, sid) for sid in parent_student_ids)


def _thread_or_403(db: Session, thread_id: UUID, user: User) -> MessageThread:
    thread = db.query(MessageThread).filter(MessageThread.id == thread_id).first()
    if not thread:
        raise HTTPException(status_code=404, detail="Thread not found")
    if user.id not in (thread.parent_user_id, thread.staff_user_id):
        raise HTTPException(status_code=403, detail="Not a party to this thread")
    return thread


def _rate_limit_or_429(db: Session, user_id: UUID) -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(seconds=RATE_LIMIT_WINDOW_SECONDS)
    recent = db.query(sqlfunc.count(Message.id)).filter(
        Message.sender_id == user_id,
        Message.created_at >= cutoff,
    ).scalar() or 0
    if recent >= RATE_LIMIT_COUNT:
        raise HTTPException(status_code=429, detail="Too many messages. Slow down.")


def _thread_summary(db: Session, thread: MessageThread, me: User) -> dict:
    other_id = thread.staff_user_id if me.id == thread.parent_user_id else thread.parent_user_id
    other = db.query(User).filter(User.id == other_id).first()
    last_msg = (
        db.query(Message)
        .filter(Message.thread_id == thread.id)
        .order_by(Message.created_at.desc())
        .first()
    )
    last_read = thread.parent_last_read_at if me.id == thread.parent_user_id else thread.staff_last_read_at
    unread_q = db.query(sqlfunc.count(Message.id)).filter(
        Message.thread_id == thread.id,
        Message.sender_id != me.id,
    )
    if last_read is not None:
        unread_q = unread_q.filter(Message.created_at > last_read)
    unread = unread_q.scalar() or 0

    student_name = None
    if thread.student_id:
        s = db.query(Student).filter(Student.id == thread.student_id).first()
        student_name = s.name if s else None

    return {
        "id": str(thread.id),
        "other_user_id": str(other_id),
        "other_user_name": other.full_name if other else None,
        "other_user_role": other.role if other else None,
        "student_id": str(thread.student_id) if thread.student_id else None,
        "student_name": student_name,
        "last_message": (last_msg.body[:120] if last_msg else None),
        "last_message_at": thread.last_message_at.isoformat() if thread.last_message_at else None,
        "last_sender_id": str(last_msg.sender_id) if last_msg else None,
        "unread_count": int(unread),
    }


def _message_type(body: Optional[str]) -> str:
    text = (body or "").strip()
    return "event" if any(text.startswith(prefix) for prefix in EVENT_PREFIXES) else "chat"


# ---------------- Endpoints ----------------
@router.get("/threads")
def list_threads(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """List all threads the current user is party to."""
    q = db.query(MessageThread).filter(
        or_(MessageThread.parent_user_id == user.id, MessageThread.staff_user_id == user.id)
    ).order_by(MessageThread.last_message_at.desc())
    threads = q.all()
    return [_thread_summary(db, t, user) for t in threads]


@router.get("/unread_count")
def total_unread(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Total unread messages across all threads for current user."""
    threads = db.query(MessageThread).filter(
        or_(MessageThread.parent_user_id == user.id, MessageThread.staff_user_id == user.id)
    ).all()
    total = 0
    for t in threads:
        last_read = t.parent_last_read_at if user.id == t.parent_user_id else t.staff_last_read_at
        q = db.query(sqlfunc.count(Message.id)).filter(
            Message.thread_id == t.id,
            Message.sender_id != user.id,
        )
        if last_read is not None:
            q = q.filter(Message.created_at > last_read)
        total += int(q.scalar() or 0)
    return {"unread_count": total}


@router.post("/threads")
def start_or_get_thread(
    data: StartThreadRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get existing thread or create a new one. Returns the thread summary."""
    other = db.query(User).filter(User.id == data.other_user_id).first()
    if not other:
        raise HTTPException(status_code=404, detail="User not found")
    if other.id == user.id:
        raise HTTPException(status_code=400, detail="Cannot start a thread with yourself")

    # Determine parent / staff sides.
    if user.role == "parent" and _is_staff(other):
        parent_id, staff_id = user.id, other.id
        if not _parent_can_message_staff(db, user, other, data.student_id):
            raise HTTPException(status_code=403, detail="Not allowed to message this staff member")
    elif _is_staff(user) and other.role == "parent":
        parent_id, staff_id = other.id, user.id
        if not _staff_can_message_parent(db, user, other, data.student_id):
            raise HTTPException(status_code=403, detail="Not allowed to message this parent")
    else:
        raise HTTPException(status_code=400, detail="Chat is between a parent and a staff user")

    # Optional student must belong to the parent.
    if data.student_id is not None:
        link = db.query(ParentStudentLink).filter(
            ParentStudentLink.user_id == parent_id,
            ParentStudentLink.student_id == data.student_id,
        ).first()
        if not link:
            raise HTTPException(status_code=403, detail="Student is not linked to this parent")

    thread = db.query(MessageThread).filter(
        MessageThread.parent_user_id == parent_id,
        MessageThread.staff_user_id == staff_id,
        MessageThread.student_id == data.student_id,
    ).first()
    if not thread:
        thread = MessageThread(
            parent_user_id=parent_id,
            staff_user_id=staff_id,
            student_id=data.student_id,
        )
        db.add(thread)
        db.commit()
        db.refresh(thread)

    return _thread_summary(db, thread, user)


@router.get("/threads/{thread_id}/messages")
def list_messages(
    thread_id: UUID,
    after_id: Optional[UUID] = Query(None, description="Return only messages with id greater (newer) than this cursor"),
    limit: int = Query(100, ge=1, le=200),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Paginated thread messages. Polling-friendly via after_id cursor."""
    thread = _thread_or_403(db, thread_id, user)

    q = db.query(Message).filter(Message.thread_id == thread.id)
    if after_id is not None:
        pivot = db.query(Message).filter(Message.id == after_id, Message.thread_id == thread.id).first()
        if pivot is not None:
            q = q.filter(Message.created_at > pivot.created_at)
    q = q.order_by(Message.created_at.asc()).limit(limit)
    items = q.all()
    return [
        {
            "id": str(m.id),
            "thread_id": str(m.thread_id),
            "sender_id": str(m.sender_id),
            "body": m.body,
            "type": _message_type(m.body),
            "is_mine": m.sender_id == user.id,
            "created_at": m.created_at.isoformat() if m.created_at else None,
        }
        for m in items
    ]


@router.post("/threads/{thread_id}/messages")
def post_message(
    thread_id: UUID,
    data: SendMessageRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    thread = _thread_or_403(db, thread_id, user)
    _rate_limit_or_429(db, user.id)

    msg = Message(thread_id=thread.id, sender_id=user.id, body=data.body)
    db.add(msg)
    thread.last_message_at = sqlfunc.now()
    # sender has implicitly read everything up to now
    now = datetime.now(timezone.utc)
    if user.id == thread.parent_user_id:
        thread.parent_last_read_at = now
    else:
        thread.staff_last_read_at = now
    db.commit()
    db.refresh(msg)

    recipient_id = thread.staff_user_id if user.id == thread.parent_user_id else thread.parent_user_id
    recipient = db.query(User).filter(User.id == recipient_id).first()
    if recipient and recipient.onesignal_player_id:
        sid = (recipient.onesignal_player_id or "").strip()
        if sid:
            title = f"New message from {user.full_name or 'user'}"
            preview = data.body[:100]
            try:
                send_onesignal_notification([sid], title, preview)
            except Exception:
                pass

    return {
        "id": str(msg.id),
        "thread_id": str(msg.thread_id),
        "sender_id": str(msg.sender_id),
        "body": msg.body,
        "type": "chat",
        "is_mine": True,
        "created_at": msg.created_at.isoformat() if msg.created_at else None,
    }


@router.post("/threads/{thread_id}/read")
def mark_read(
    thread_id: UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    thread = _thread_or_403(db, thread_id, user)
    now = datetime.now(timezone.utc)
    if user.id == thread.parent_user_id:
        thread.parent_last_read_at = now
    else:
        thread.staff_last_read_at = now
    db.commit()
    return {"success": True}


@router.post("/threads/{thread_id}/leave")
def create_leave_from_thread(
    thread_id: UUID,
    data: CreateThreadLeaveRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a leave request directly from a student-scoped parent/staff chat thread."""
    thread = _thread_or_403(db, thread_id, user)
    if user.role != "parent" or user.id != thread.parent_user_id:
        raise HTTPException(status_code=403, detail="Only the parent in this thread can request leave")
    if not thread.student_id:
        raise HTTPException(status_code=400, detail="Leave requests from chat require a student-specific thread")

    staff = db.query(User).filter(User.id == thread.staff_user_id).first()
    if not staff or not _is_staff(staff):
        raise HTTPException(status_code=400, detail="Invalid staff participant for this thread")
    if staff.role != "admin" and not _authority_over_student(db, staff, thread.student_id):
        raise HTTPException(status_code=403, detail="This staff member is no longer assigned to the student")

    app = create_leave_application(
        db,
        parent_user=user,
        student_id=thread.student_id,
        reason=data.reason,
        start_date=data.start_date,
        end_date=data.end_date,
    )
    return {
        "success": True,
        "leave": {
            "id": str(app.id),
            "student_id": str(app.student_id),
            "parent_user_id": str(app.parent_user_id),
            "reason": app.reason,
            "start_date": app.start_date.isoformat() if app.start_date else None,
            "end_date": app.end_date.isoformat() if app.end_date else None,
            "status": app.status,
            "created_at": app.created_at.isoformat() if app.created_at else None,
        },
    }
    

# -------- Helpers for starting threads from staff-side UI --------
@router.get("/staff/eligible_parents")
def eligible_parents_for_staff(
    q: Optional[str] = Query(None, description="Name / phone search"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List parents the current staff user may start a chat with, optionally filtered by name/phone.
    Returns parent users with their linked students so the UI can pick a context student.
    """
    if not _is_staff(user):
        raise HTTPException(status_code=403, detail="Staff only")

    # Resolve student scope for staff.
    if user.role == "admin":
        student_q = db.query(Student)
    elif user.role == "coordinator":
        a = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == user.id,
            BranchAssignment.class_id.is_(None),
        ).first()
        if not a:
            return []
        student_q = db.query(Student).filter(Student.branch_id == a.branch_id)
    else:  # teacher
        a = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == user.id,
            BranchAssignment.class_id.isnot(None),
        ).first()
        if not a:
            return []
        student_q = db.query(Student).filter(Student.class_id == a.class_id)

    students = student_q.all()
    student_ids = [s.id for s in students]
    if not student_ids:
        return []

    links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id.in_(student_ids)).all()
    parent_ids = {l.user_id for l in links}
    if not parent_ids:
        return []

    user_q = db.query(User).filter(User.id.in_(parent_ids), User.is_active == "true")
    if q:
        like = f"%{q.strip()}%"
        user_q = user_q.filter(or_(User.full_name.ilike(like), User.phone.ilike(like)))
    parents = user_q.order_by(User.full_name).all()

    student_by_id = {s.id: s for s in students}
    links_by_parent: dict = {}
    for l in links:
        links_by_parent.setdefault(l.user_id, []).append(l.student_id)

    result = []
    for p in parents:
        child_ids = [sid for sid in links_by_parent.get(p.id, []) if sid in student_by_id]
        result.append({
            "user_id": str(p.id),
            "full_name": p.full_name,
            "phone": p.phone,
            "students": [
                {"id": str(sid), "name": student_by_id[sid].name, "admission_number": student_by_id[sid].admission_number}
                for sid in child_ids
            ],
        })
    return result


@router.get("/parent/eligible_staff")
def eligible_staff_for_parent(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List staff the current parent may start a chat with (scoped to their children)."""
    if user.role != "parent":
        raise HTTPException(status_code=403, detail="Parents only")

    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == user.id).all()
    if not links:
        return []
    student_ids = [l.student_id for l in links]
    students = db.query(Student).filter(Student.id.in_(student_ids)).all()
    branch_ids = {s.branch_id for s in students if s.branch_id}
    class_ids = {s.class_id for s in students if s.class_id}

    staff_user_ids: set = set()

    # Admins: always eligible.
    admins = db.query(User).filter(User.role == "admin", User.is_active == "true").all()
    staff_user_ids.update(a.id for a in admins)

    # Coordinators of the child's branch.
    if branch_ids:
        coord_assignments = db.query(BranchAssignment).filter(
            BranchAssignment.branch_id.in_(branch_ids),
            BranchAssignment.class_id.is_(None),
        ).all()
        coord_ids = {a.user_id for a in coord_assignments}
        if coord_ids:
            coords = db.query(User).filter(
                User.id.in_(coord_ids), User.role == "coordinator", User.is_active == "true"
            ).all()
            staff_user_ids.update(c.id for c in coords)

    # Teachers of the child's class.
    if class_ids:
        teacher_assignments = db.query(BranchAssignment).filter(
            BranchAssignment.class_id.in_(class_ids),
        ).all()
        teacher_ids = {a.user_id for a in teacher_assignments}
        if teacher_ids:
            teachers = db.query(User).filter(
                User.id.in_(teacher_ids), User.role == "teacher", User.is_active == "true"
            ).all()
            staff_user_ids.update(t.id for t in teachers)

    if not staff_user_ids:
        return []

    staff_list = db.query(User).filter(User.id.in_(staff_user_ids)).order_by(User.role, User.full_name).all()
    return [
        {
            "user_id": str(s.id),
            "full_name": s.full_name,
            "role": s.role,
        }
        for s in staff_list
    ]
