"""Bedtime / daily stories with branch and class visibility."""
import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class DailyStory(Base):
    __tablename__ = "daily_stories"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    story_type = Column(String(20), nullable=False, default="daily")  # daily | bedtime
    media_kind = Column(String(20), nullable=False)  # video | image
    file_path = Column(String(500), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_mime = Column(String(100), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    branches = relationship(
        "DailyStoryBranch",
        back_populates="story",
        cascade="all, delete-orphan",
        lazy="selectin",
    )
    classes = relationship(
        "DailyStoryClass",
        back_populates="story",
        cascade="all, delete-orphan",
        lazy="selectin",
    )


class DailyStoryBranch(Base):
    __tablename__ = "daily_story_branches"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(UUID(as_uuid=True), ForeignKey("daily_stories.id", ondelete="CASCADE"), nullable=False, index=True)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"), nullable=False, index=True)

    story = relationship("DailyStory", back_populates="branches")


class DailyStoryClass(Base):
    __tablename__ = "daily_story_classes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    story_id = Column(UUID(as_uuid=True), ForeignKey("daily_stories.id", ondelete="CASCADE"), nullable=False, index=True)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.id"), nullable=False, index=True)

    story = relationship("DailyStory", back_populates="classes")
