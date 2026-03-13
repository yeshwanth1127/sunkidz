import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Date, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class DaycareGroup(Base):
    """Daycare group - like BusRoute. Admin creates and assigns daycare staff + students."""
    __tablename__ = "daycare_groups"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"), nullable=False)
    daycare_staff_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    branch = relationship("Branch", backref="daycare_groups")
    daycare_staff = relationship("User", backref="daycare_groups")
    students = relationship("DaycareGroupStudent", back_populates="group", cascade="all, delete-orphan")


class DaycareGroupStudent(Base):
    """Links students to a daycare group."""
    __tablename__ = "daycare_group_students"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    group_id = Column(UUID(as_uuid=True), ForeignKey("daycare_groups.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    group = relationship("DaycareGroup", back_populates="students")
    student = relationship("Student")


class DaycareDailyUpdate(Base):
    """Daily update for a daycare student, posted by daycare staff."""
    __tablename__ = "daycare_daily_updates"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    author_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    date = Column(Date, nullable=False)
    content = Column(Text, nullable=False)
    photo_path = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    student = relationship("Student")
    author = relationship("User")
