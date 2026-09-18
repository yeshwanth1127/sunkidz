from datetime import date
from typing import Optional
from pydantic import BaseModel


class DaycareGroupCreate(BaseModel):
    name: str
    branch_id: str
    daycare_staff_id: str


class DaycareGroupUpdate(BaseModel):
    name: Optional[str] = None
    daycare_staff_id: Optional[str] = None


class DaycareGroupStudentCreate(BaseModel):
    student_id: str


class DaycareGroupResponse(BaseModel):
    id: str
    name: str
    branch_id: str
    branch_name: Optional[str] = None
    daycare_staff_id: str
    daycare_staff_name: Optional[str] = None
    student_count: int = 0
    students: list = []


class DaycareDailyUpdateCreate(BaseModel):
    student_id: str
    date: str  # YYYY-MM-DD
    content: str


class DaycareDailyUpdateResponse(BaseModel):
    id: str
    student_id: str
    student_name: Optional[str] = None
    author_id: str
    author_name: Optional[str] = None
    date: str
    content: str
    photo_path: Optional[str] = None
    created_at: str
