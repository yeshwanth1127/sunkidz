from datetime import date
from uuid import UUID
from pydantic import BaseModel


class DiaryEntryCreate(BaseModel):
    class_id: UUID
    entry_date: date
    student_id: UUID | None = None
    remarks: str | None = None
    activities: str | None = None
    homework_notes: str | None = None


class DiaryEntryResponse(BaseModel):
    id: str
    class_id: str
    branch_id: str
    author_id: str
    author_name: str | None = None
    class_name: str | None = None
    branch_name: str | None = None
    student_id: str | None = None
    student_name: str | None = None
    entry_date: str
    remarks: str | None = None
    activities: str | None = None
    homework_notes: str | None = None
    created_at: str | None = None
    updated_at: str | None = None

    class Config:
        from_attributes = True


class DiaryStudentItem(BaseModel):
    id: str
    name: str
    admission_number: str | None = None
