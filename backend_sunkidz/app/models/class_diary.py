"""Daily class diary entries (remarks, activities, homework notes)."""
import uuid
from sqlalchemy import Column, String, DateTime, Date, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.core.database import Base


class ClassDiaryEntry(Base):
    __tablename__ = "class_diary_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.id"), nullable=False, index=True)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"), nullable=False, index=True)
    student_id = Column(
        UUID(as_uuid=True),
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    author_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    entry_date = Column(Date, nullable=False, index=True)
    remarks = Column(Text, nullable=True)
    activities = Column(Text, nullable=True)
    homework_notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
