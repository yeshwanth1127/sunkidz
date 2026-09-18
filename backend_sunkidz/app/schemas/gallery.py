from typing import Optional
from uuid import UUID
from pydantic import BaseModel


class GalleryBranchOption(BaseModel):
    id: UUID
    name: str


class GalleryItemResponse(BaseModel):
    id: UUID
    branch_id: UUID
    branch_name: Optional[str] = None
    media_type: str  # image | video
    title: Optional[str] = None
    description: Optional[str] = None
    file_name: str
    file_size: Optional[str] = None
    uploaded_by: Optional[UUID] = None
    uploader_name: Optional[str] = None
    can_manage: bool = False
    created_at: Optional[str] = None
    updated_at: Optional[str] = None

    class Config:
        from_attributes = True


class GalleryItemUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
