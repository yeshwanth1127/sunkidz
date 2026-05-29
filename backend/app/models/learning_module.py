from uuid import uuid4
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer, Date, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base


class LearningModule(Base):
    __tablename__ = "learning_module"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    name = Column(String(255), nullable=False)
    description = Column(String(1000), nullable=True)
    created_by = Column(String(36), nullable=False)  # TODO: Add ForeignKey("user.id") after fixing database
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    videos = relationship("LearningVideo", back_populates="module", cascade="all, delete-orphan")
    assignments = relationship("LearningModuleAssignment", back_populates="module", cascade="all, delete-orphan")


class LearningVideo(Base):
    __tablename__ = "learning_video"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    module_id = Column(String(36), ForeignKey("learning_module.id"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(String(1000), nullable=True)
    file_path = Column(String(500), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=False)
    duration = Column(Integer, nullable=True)
    school_day = Column(Integer, nullable=True)
    academic_year_start = Column(Date, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    module = relationship("LearningModule", back_populates="videos")


class LearningModuleAssignment(Base):
    __tablename__ = "learning_module_assignment"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    module_id = Column(String(36), ForeignKey("learning_module.id"), nullable=False)
    class_id = Column(String(36), nullable=True)
    branch_id = Column(String(36), nullable=True)
    assigned_by = Column(String(36), nullable=False)
    assigned_at = Column(DateTime, default=datetime.utcnow)

    module = relationship("LearningModule", back_populates="assignments")


class DayFolder(Base):
    __tablename__ = "day_folder"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    name = Column(String(255), nullable=False)
    class_id = Column(String(36), nullable=False)
    school_day = Column(Integer, nullable=False)
    academic_year_start = Column(Date, nullable=False)
    created_by = Column(String(36), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    contents = relationship("DayFolderContent", back_populates="folder", cascade="all, delete-orphan")

    __table_args__ = (
        UniqueConstraint("class_id", "school_day", "academic_year_start", "name", name="uq_day_folder_name"),
    )


class DayFolderContent(Base):
    __tablename__ = "day_folder_content"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    folder_id = Column(String(36), ForeignKey("day_folder.id", ondelete="CASCADE"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(String(1000), nullable=True)
    file_path = Column(String(500), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=False)
    content_type = Column(String(20), nullable=False)  # "video" or "document"
    created_at = Column(DateTime, default=datetime.utcnow)

    folder = relationship("DayFolder", back_populates="contents")
