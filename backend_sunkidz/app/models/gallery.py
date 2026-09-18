"""Branch gallery: photos and videos shared per branch by staff.

Separate from the class-scoped `gallery_images` table (see
`app/models/syllabus.py`), which only holds images for a single class and is
surfaced through the syllabus feature. This table backs the standalone
Gallery module reachable from the sidebar and is branch-scoped so a whole
branch's staff and parents see the same feed.
"""
import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class GalleryItem(Base):
    __tablename__ = "gallery_items"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    branch_id = Column(
        UUID(as_uuid=True), ForeignKey("branches.id"), nullable=False, index=True
    )
    uploaded_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    media_type = Column(String(20), nullable=False)  # image | video
    title = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    file_path = Column(String(500), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_mime = Column(String(100), nullable=True)
    file_size = Column(String(50), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    branch = relationship("Branch")
    uploader = relationship("User")
