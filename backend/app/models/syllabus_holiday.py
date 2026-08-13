"""Holidays within the academic calendar - when marked, school days shift."""
import uuid
from sqlalchemy import Column, String, DateTime, Date, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.core.database import Base


class SyllabusHoliday(Base):
    """A date or date range marked as holiday. Excluded from school day counting."""
    __tablename__ = "syllabus_holidays"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    academic_year_start = Column(
        "academic_year_start",
        Date,
        nullable=False,
    )  # June 1 of start year
    branch_id = Column(
        UUID(as_uuid=True),
        ForeignKey("branches.id"),
        nullable=True,
        index=True,
    )
    holiday_date = Column(Date, nullable=False)
    reason = Column(String(255), nullable=True)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
