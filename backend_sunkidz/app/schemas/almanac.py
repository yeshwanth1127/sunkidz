from datetime import date
from uuid import UUID
from pydantic import BaseModel


class AlmanacHolidayCreate(BaseModel):
    holiday_date: date
    reason: str | None = None
    branch_id: UUID | None = None  # None = applies to ALL branches
    academic_year_start: date | None = None


class AlmanacHolidayResponse(BaseModel):
    id: str
    holiday_date: str
    reason: str | None = None
    branch_id: str | None = None
    branch_name: str | None = None
    is_global: bool = False
    academic_year_start: str


class AlmanacEventCreate(BaseModel):
    branch_id: UUID | None = None  # ignored when is_global=True
    class_id: UUID | None = None
    event_date: date
    title: str
    description: str | None = None
    event_type: str = "event"
    is_global: bool = False
    academic_year_start: date | None = None


class AlmanacEventUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    event_type: str | None = None
    event_date: date | None = None
    class_id: UUID | None = None
    is_global: bool | None = None


class AlmanacEventResponse(BaseModel):
    id: str
    branch_id: str
    branch_name: str | None = None
    class_id: str | None = None
    class_name: str | None = None
    event_date: str
    title: str
    description: str | None = None
    event_type: str
    is_global: bool = False
    academic_year_start: str


class AlmanacCalendarDay(BaseModel):
    day: int
    date: str
    syllabus_count: int = 0
    holidays: list[AlmanacHolidayResponse] = []
    events: list[AlmanacEventResponse] = []


class AlmanacCalendarResponse(BaseModel):
    branch_id: str
    class_id: str | None = None
    academic_year: str
    academic_year_start: str
    days: list[AlmanacCalendarDay]
