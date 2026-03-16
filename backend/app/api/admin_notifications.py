from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from uuid import UUID
from app.core.database import get_db
from app.models.notification import Notification
from app.schemas.notification import NotificationResponse
from app.models.user import User

router = APIRouter(prefix="/admin/notifications", tags=["notifications"])

@router.get("", response_model=list[NotificationResponse])
def list_notifications(db: Session = Depends(get_db), user: User = Depends()):
    return db.query(Notification).filter(Notification.user_id == user.id).order_by(Notification.created_at.desc()).all()

@router.get("/unread_count", response_model=int)
def unread_count(db: Session = Depends(get_db), user: User = Depends()):
    return db.query(Notification).filter(Notification.user_id == user.id, Notification.is_read == False).count()

@router.post("/mark_read/{notification_id}")
def mark_read(notification_id: UUID, db: Session = Depends(get_db), user: User = Depends()):
    notif = db.query(Notification).filter(Notification.id == notification_id, Notification.user_id == user.id).first()
    if notif:
        notif.is_read = True
        db.commit()
        return {"success": True}
    return {"success": False, "error": "Notification not found"}
