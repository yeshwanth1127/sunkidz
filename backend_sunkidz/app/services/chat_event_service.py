"""Helpers to append system/business events into chat threads."""

from datetime import datetime, timezone
import logging
from typing import Optional
from uuid import UUID

from sqlalchemy import func as sqlfunc
from sqlalchemy.orm import Session

from app.models.message import Message, MessageThread
from app.models.user import User
from app.services.notification_service import send_onesignal_notification

logger = logging.getLogger(__name__)


def _is_staff(user: Optional[User]) -> bool:
    return bool(user and user.role in ("admin", "coordinator", "teacher"))


def _get_or_create_thread(
    db: Session,
    parent_user_id: UUID,
    staff_user_id: UUID,
    student_id: Optional[UUID],
) -> MessageThread:
    thread = db.query(MessageThread).filter(
        MessageThread.parent_user_id == parent_user_id,
        MessageThread.staff_user_id == staff_user_id,
        MessageThread.student_id == student_id,
    ).first()
    if thread:
        return thread

    thread = MessageThread(
        parent_user_id=parent_user_id,
        staff_user_id=staff_user_id,
        student_id=student_id,
    )
    db.add(thread)
    db.flush()
    return thread


def post_event_message(
    db: Session,
    *,
    parent_user_id: UUID,
    staff_user_id: UUID,
    sender_id: UUID,
    body: str,
    student_id: Optional[UUID] = None,
    send_push: bool = False,
    push_title: Optional[str] = None,
) -> bool:
    """Append an event message into a parent-staff thread.

    Returns True if the event message was stored, False if validation failed.
    """
    text = (body or "").strip()
    if not text:
        return False

    parent = db.query(User).filter(User.id == parent_user_id).first()
    staff = db.query(User).filter(User.id == staff_user_id).first()
    sender = db.query(User).filter(User.id == sender_id).first()

    if not parent or parent.role != "parent":
        return False
    if not _is_staff(staff):
        return False
    if not sender or sender.id not in (parent_user_id, staff_user_id):
        return False

    thread = _get_or_create_thread(
        db,
        parent_user_id=parent_user_id,
        staff_user_id=staff_user_id,
        student_id=student_id,
    )

    msg = Message(thread_id=thread.id, sender_id=sender_id, body=text)
    db.add(msg)
    thread.last_message_at = sqlfunc.now()

    now = datetime.now(timezone.utc)
    if sender_id == parent_user_id:
        thread.parent_last_read_at = now
        recipient_id = staff_user_id
    else:
        thread.staff_last_read_at = now
        recipient_id = parent_user_id

    db.commit()

    if send_push:
        recipient = db.query(User).filter(User.id == recipient_id).first()
        sid = (recipient.onesignal_player_id or "").strip() if recipient else ""
        if sid:
            title = push_title or f"New message from {sender.full_name or 'user'}"
            try:
                send_onesignal_notification([sid], title, text[:120])
            except Exception:
                logger.exception("Failed to send chat event push notification")

    return True
