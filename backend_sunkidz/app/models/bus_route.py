import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Boolean, Integer, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class BusRoute(Base):
    __tablename__ = "bus_routes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    shift = Column(String(20), nullable=False)  # "morning", "afternoon"
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"), nullable=False)
    bus_staff_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    branch = relationship("Branch", backref="bus_routes")
    bus_staff = relationship("User", backref="bus_routes")
    students = relationship("RouteStudent", back_populates="route", cascade="all, delete-orphan")
    ride_sessions = relationship("RideSession", back_populates="route", cascade="all, delete-orphan")


class RouteStudent(Base):
    __tablename__ = "route_students"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    route_id = Column(UUID(as_uuid=True), ForeignKey("bus_routes.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    pickup_order = Column(Integer, nullable=False)  # Sequence number (1, 2, 3...)
    pickup_address = Column(Text, nullable=True)
    pickup_time = Column(String(10), nullable=True)  # HH:MM format
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    route = relationship("BusRoute", back_populates="students")
    student = relationship("Student")
