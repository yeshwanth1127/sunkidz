from uuid import UUID
from datetime import date
from pydantic import BaseModel, Field
from typing import Optional


class SyllabusBase(BaseModel):
    title: str
    description: Optional[str] = None
    upload_date: date
    class_id: UUID


class SyllabusCreate(SyllabusBase):
    pass


class SyllabusUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    upload_date: Optional[date] = None


class SyllabusResponse(SyllabusBase):
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
