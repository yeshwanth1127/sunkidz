import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Float
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class RideSession(Base):
    __tablename__ = "ride_sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    route_id = Column(UUID(as_uuid=True), ForeignKey("bus_routes.id", ondelete="CASCADE"), nullable=False)
    bus_staff_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    start_time = Column(DateTime(timezone=True), nullable=False)
    end_time = Column(DateTime(timezone=True), nullable=True)
    status = Column(String(20), nullable=False, default="active")  # "active", "completed", "cancelled"
    total_distance_km = Column(Float, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    route = relationship("BusRoute", back_populates="ride_sessions")
    bus_staff = relationship("User")
    location_updates = relationship("LocationUpdate", back_populates="ride_session", cascade="all, delete-orphan")


class LocationUpdate(Base):
    __tablename__ = "location_updates"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    ride_session_id = Column(UUID(as_uuid=True), ForeignKey("ride_sessions.id", ondelete="CASCADE"), nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    accuracy = Column(Float, nullable=True)  # meters
    speed = Column(Float, nullable=True)  # km/h
    heading = Column(Float, nullable=True)  # degrees (0-360)
    altitude = Column(Float, nullable=True)  # meters
    timestamp = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    ride_session = relationship("RideSession", back_populates="location_updates")
