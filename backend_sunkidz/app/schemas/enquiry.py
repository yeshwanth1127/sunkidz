from datetime import date
from pydantic import BaseModel
from uuid import UUID


class EnquiryCreate(BaseModel):
    child_name: str
    date_of_birth: date | None = None
    age_years: int | None = None
    age_months: int | None = None
    gender: str | None = None
    father_name: str | None = None
    father_occupation: str | None = None
    father_place_of_work: str | None = None
    father_email: str | None = None
    father_contact_no: str | None = None
    mother_name: str | None = None
    mother_occupation: str | None = None
    mother_place_of_work: str | None = None
    mother_email: str | None = None
    mother_contact_no: str | None = None
    siblings_info: str | None = None
    siblings_age: str | None = None
    residential_address: str | None = None
    residential_contact_no: str | None = None
    challenges_specialities: str | None = None
    expectations_from_school: str | None = None
    branch_id: UUID | None = None
    status: str = "pending"


class EnquiryUpdate(BaseModel):
    child_name: str | None = None
    date_of_birth: date | None = None
    age_years: int | None = None
    age_months: int | None = None
    gender: str | None = None
    father_name: str | None = None
    father_occupation: str | None = None
    father_place_of_work: str | None = None
    father_email: str | None = None
    father_contact_no: str | None = None
    mother_name: str | None = None
    mother_occupation: str | None = None
    mother_place_of_work: str | None = None
    mother_email: str | None = None
    mother_contact_no: str | None = None
    siblings_info: str | None = None
    siblings_age: str | None = None
    residential_address: str | None = None
    residential_contact_no: str | None = None
    challenges_specialities: str | None = None
    expectations_from_school: str | None = None
    branch_id: UUID | None = None
    status: str | None = None


class EnquiryResponse(BaseModel):
    id: str
    child_name: str
    date_of_birth: str | None
    age_years: int | None
    age_months: int | None
    gender: str | None
    father_name: str | None
    mother_name: str | None
    father_contact_no: str | None
    mother_contact_no: str | None
    residential_address: str | None
    branch_id: str | None
    branch_name: str | None
    status: str
    created_at: str | None

    class Config:
        from_attributes = True


class EnquiryDetailResponse(EnquiryResponse):
    father_occupation: str | None = None
    father_place_of_work: str | None = None
    father_email: str | None = None
    mother_occupation: str | None = None
    mother_place_of_work: str | None = None
    mother_email: str | None = None
    siblings_info: str | None = None
    siblings_age: str | None = None
    residential_contact_no: str | None = None
    challenges_specialities: str | None = None
    expectations_from_school: str | None = None
