"""Materialised school calendar, synced from the school's Google Sheet.

The Google Sheet ("Base Document" tab) is the source of truth for which dates
are working days and what Learning Day number each working day receives.
This table is a cache/materialisation of that sheet so that:

* existing Learning Module uploads (keyed by an integer day number) keep
  resolving to a real date,
* repeated refreshes are idempotent (upsert on year + branch + date),
* the calendar renders without hitting Google on every request.

One row per (academic_year_start, branch_scope, calendar_date).
``branch_scope`` is the empty string for the school-wide calendar, or a branch
id when the sheet provides a branch-specific tab (none do today, but the
column lets a future "AECS Calendar" tab override the school-wide rows for
that branch without any code change).
"""
from datetime import datetime
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Integer,
    String,
    UniqueConstraint,
    Index,
)

from app.core.database import Base

# Sentinel stored in ``branch_scope`` for the school-wide calendar. A real empty
# string (not NULL) so the unique constraint and upsert ON CONFLICT work.
ALL_BRANCHES = ""


class SchoolCalendarDay(Base):
    __tablename__ = "school_calendar_day"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))

    academic_year_start = Column(Date, nullable=False)  # June 1 of start year
    branch_scope = Column(String(36), nullable=False, default=ALL_BRANCHES)
    calendar_date = Column(Date, nullable=False)

    weekday = Column(String(10), nullable=True)  # "Monday" ...
    is_working_day = Column(Boolean, nullable=False, default=False)
    # Recomputed running count of working days. NULL on non-working days.
    learning_day = Column(Integer, nullable=True)
    # The number the sheet itself had in its "Day #" column (advisory only).
    sheet_day_number = Column(Integer, nullable=True)

    label = Column(String(500), nullable=True)         # Description column
    category = Column(String(50), nullable=True)       # holiday|celebration|assessment|ptm|event|working
    school_event = Column(String(500), nullable=True)  # School Event column
    document_numbers = Column(String(1000), nullable=True)
    document_availability = Column(String(255), nullable=True)

    synced_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    __table_args__ = (
        UniqueConstraint(
            "academic_year_start",
            "branch_scope",
            "calendar_date",
            name="uq_school_calendar_day",
        ),
        Index("ix_school_calendar_day_lookup", "academic_year_start", "branch_scope"),
    )
