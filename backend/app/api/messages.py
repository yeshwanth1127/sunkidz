"""Messaging API: send messages (admin, coordinator, parent) and view notifications (all users)."""
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import get_current_user, require_admin, require_coordinator, require_parent
from app.models.user import User
from app.models.notification import Notification
from app.models.branch import BranchAssignment
from app.services.messaging_service import (
    get_admin_recipients,
    get_coordinator_recipients,
    get_parent_recipients,
    create_notifications_for_users,
)

router = APIRouter(tags=["messages"])


# --- Schemas ---
class SendMessageRequest(BaseModel):
    title: str
    message: str


class AdminSendMessageRequest(SendMessageRequest):
    target_type: str  # all_staff, all_parents, all, branch_staff, branch_parents, branch_all, grade_teachers
    branch_id: UUID | None = None
    class_id: UUID | None = None


class CoordinatorSendMessageRequest(SendMessageRequest):
    target_type: str  # branch_teachers, branch_parents


class SendMessageResponse(BaseModel):
    success: bool
    recipients_count: int
    message: str


# --- Notifications (any authenticated user) ---
@router.get("/me/notifications")
def list_my_notifications(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List notifications for the current user."""
    notifications = (
        db.query(Notification)
        .filter(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .all()
    )
    result = []
    for n in notifications:
        sender_name = None
        if n.sender_id:
            sender = db.query(User).filter(User.id == n.sender_id).first()
            sender_name = sender.full_name if sender else None
        result.append({
            "id": str(n.id),
            "user_id": str(n.user_id),
            "sender_id": str(n.sender_id) if n.sender_id else None,
            "sender_name": sender_name,
            "title": n.title,
            "message": n.message,
            "related_enquiry_id": str(n.related_enquiry_id) if n.related_enquiry_id else None,
            "is_read": n.is_read,
            "created_at": n.created_at.isoformat() if n.created_at else None,
        })
    return result


@router.get("/me/notifications/unread_count")
def my_unread_count(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get unread notification count for the current user."""
    return db.query(Notification).filter(
        Notification.user_id == user.id,
        Notification.is_read == False,
    ).count()


@router.post("/me/notifications/mark_read/{notification_id}")
def mark_my_notification_read(
    notification_id: UUID,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark a notification as read."""
    n = db.query(Notification).filter(
        Notification.id == notification_id,
        Notification.user_id == user.id,
    ).first()
    if not n:
        raise HTTPException(status_code=404, detail="Notification not found")
    n.is_read = True
    db.commit()
    return {"success": True}


# --- Admin: Send messages ---
@router.post("/admin/messages/send", response_model=SendMessageResponse)
def admin_send_message(
    data: AdminSendMessageRequest,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Admin sends message to staff/parents by target type."""
    title = (data.title or "").strip()
    message = (data.message or "").strip()
    if not title or not message:
        raise HTTPException(status_code=400, detail="Title and message are required")

    target = data.target_type
    if target in ("branch_staff", "branch_parents", "branch_all") and not data.branch_id:
        raise HTTPException(status_code=400, detail="branch_id required for this target type")
    if target == "grade_teachers" and not data.class_id:
        raise HTTPException(status_code=400, detail="class_id required for grade_teachers")

    recipient_ids = get_admin_recipients(db, target, data.branch_id, data.class_id)
    if not recipient_ids:
        raise HTTPException(status_code=400, detail="No recipients found for the given criteria")

    count = create_notifications_for_users(
        db, recipient_ids, title, message, sender_id=user.id
    )
    return SendMessageResponse(
        success=True,
        recipients_count=count,
        message=f"Message sent to {count} recipient(s)",
    )


# --- Coordinator: Send messages ---
def _coordinator_branch_id(user: User, db: Session) -> UUID | None:
    a = db.query(BranchAssignment).filter(
        BranchAssignment.user_id == user.id,
        BranchAssignment.class_id.is_(None),
    ).first()
    return a.branch_id if a else None


@router.post("/coordinator/messages/send", response_model=SendMessageResponse)
def coordinator_send_message(
    data: CoordinatorSendMessageRequest,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Coordinator sends message to branch teachers or branch parents."""
    title = (data.title or "").strip()
    message = (data.message or "").strip()
    if not title or not message:
        raise HTTPException(status_code=400, detail="Title and message are required")

    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        raise HTTPException(status_code=400, detail="Coordinator has no branch assigned")

    if data.target_type not in ("branch_teachers", "branch_parents"):
        raise HTTPException(status_code=400, detail="target_type must be branch_teachers or branch_parents")

    recipient_ids = get_coordinator_recipients(db, branch_id, data.target_type)
    if not recipient_ids:
        raise HTTPException(status_code=400, detail="No recipients found for your branch")

    count = create_notifications_for_users(
        db, recipient_ids, title, message, sender_id=user.id
    )
    return SendMessageResponse(
        success=True,
        recipients_count=count,
        message=f"Message sent to {count} recipient(s)",
    )


# --- Parent: Send messages ---
@router.post("/parent/messages/send", response_model=SendMessageResponse)
def parent_send_message(
    data: SendMessageRequest,
    user: User = Depends(require_parent),
    db: Session = Depends(get_db),
):
    """Parent sends message to their child's grade teachers only."""
    title = (data.title or "").strip()
    message = (data.message or "").strip()
    if not title or not message:
        raise HTTPException(status_code=400, detail="Title and message are required")

    recipient_ids, err_msg = get_parent_recipients(db, user.id)
    if not recipient_ids:
        raise HTTPException(
            status_code=400,
            detail=err_msg or "No teachers found for your child's grade.",
        )

    count = create_notifications_for_users(
        db, recipient_ids, title, message, sender_id=user.id
    )
    return SendMessageResponse(
        success=True,
        recipients_count=count,
        message=f"Message sent to {count} teacher(s)",
    )
