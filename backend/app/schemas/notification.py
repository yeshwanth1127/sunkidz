from uuid import UUID
from pydantic import BaseModel
from datetime import datetime

class NotificationBase(BaseModel):
    title: str
    message: str
    related_enquiry_id: UUID | None = None

class NotificationCreate(NotificationBase):
    user_id: UUID

class NotificationResponse(NotificationBase):
    id: UUID
    user_id: UUID
    sender_id: UUID | None = None
    is_read: bool
    created_at: datetime
    updated_at: datetime | None = None

    class Config:
        orm_mode = True
