from uuid import UUID
from datetime import date
from pydantic import BaseModel, Field
from typing import Optional


class SyllabusBase(BaseModel):
    title: str
    description: Optional[str] = None
    class_id: UUID


class SyllabusCreate(SyllabusBase):
    pass


class SyllabusUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    school_day: Optional[int] = None


class SyllabusResponse(BaseModel):
    id: UUID
    class_id: UUID
    uploaded_by: UUID
    uploader_name: Optional[str] = None
    title: str
    description: Optional[str] = None
    upload_date: Optional[date] = None
    school_day: Optional[int] = None
    academic_year_start: Optional[date] = None
    file_name: str
    file_path: str
    file_size: Optional[str] = None
    class_name: str
    created_at: str

    class Config:
        from_attributes = True


class SyllabusCalendarDay(BaseModel):
    day: int
    date: str
    syllabus: list


class SyllabusCalendarResponse(BaseModel):
    academic_year_start: str
    academic_year_str: str
    days: list[SyllabusCalendarDay]


class SyllabusHolidayCreate(BaseModel):
    holiday_date: date
    reason: Optional[str] = None


class SyllabusHolidayCreateRange(BaseModel):
    start_date: date
    num_days: int = 1
    reason: Optional[str] = None


class SyllabusHolidayResponse(BaseModel):
    id: UUID
    academic_year_start: date
    holiday_date: date
    reason: Optional[str] = None
    created_at: str

    class Config:
        from_attributes = True


class HomeworkBase(BaseModel):
    title: str
    description: Optional[str] = None
    upload_date: date
    due_date: Optional[date] = None
    class_id: UUID


class HomeworkCreate(HomeworkBase):
    pass


class HomeworkUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    upload_date: Optional[date] = None
    due_date: Optional[date] = None


class HomeworkResponse(HomeworkBase):
    id: UUID
    uploaded_by: UUID
    uploader_name: Optional[str] = None
    file_name: str
    file_path: str
    file_size: Optional[str] = None
    class_name: str
    created_at: str

    class Config:
        from_attributes = True


class GalleryResponse(BaseModel):
    id: UUID
    class_id: UUID
    uploaded_by: UUID
    uploader_name: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    upload_date: date
    file_name: str
    file_path: str
    file_size: Optional[str] = None
    class_name: str
    created_at: str

    class Config:
        from_attributes = True
