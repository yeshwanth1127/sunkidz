import uuid
from enum import Enum
from sqlalchemy import Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class UserRole(str, Enum):
    admin = "admin"
    coordinator = "coordinator"
    teacher = "teacher"
    parent = "parent"
    bus_staff = "bus_staff"


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=True, index=True)
    password_hash = Column(String(255), nullable=True)
    full_name = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False)
    phone = Column(String(50), nullable=True)
    is_active = Column(String(10), default="true")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    branch_assignments = relationship("BranchAssignment", back_populates="user", lazy="selectin")
    parent_links = relationship("ParentStudentLink", back_populates="user", lazy="selectin")
