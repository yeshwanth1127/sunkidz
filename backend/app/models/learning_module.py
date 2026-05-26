from uuid import uuid4
from sqlalchemy import Column, String, DateTime, ForeignKey, Integer
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
    created_at = Column(DateTime, default=datetime.utcnow)

    module = relationship("LearningModule", back_populates="videos")


class LearningModuleAssignment(Base):
    __tablename__ = "learning_module_assignment"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    module_id = Column(String(36), ForeignKey("learning_module.id"), nullable=False)
    student_id = Column(String(36), ForeignKey("student.id"), nullable=False)
    assigned_by = Column(String(36), nullable=False)
    assigned_at = Column(DateTime, default=datetime.utcnow)

    module = relationship("LearningModule", back_populates="assignments")
