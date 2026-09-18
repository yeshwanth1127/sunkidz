from datetime import date
from pydantic import BaseModel
from uuid import UUID


class StudentUpdate(BaseModel):
    """Partial update for student. All fields optional."""
    name: str | None = None
    date_of_birth: date | None = None
    gender: str | None = None
    place_of_birth: str | None = None
    nationality: str | None = None
    mother_tongue: str | None = None
    religion: str | None = None
    blood_group: str | None = None
    medical_allergies: str | None = None
    medical_surgeries: str | None = None
    medical_chronic_illness: str | None = None
    class_id: UUID | None = None
    residential_address: str | None = None
    residential_contact_no: str | None = None
    father_name: str | None = None
    father_occupation: str | None = None
    father_contact_no: str | None = None
    father_email: str | None = None
    mother_name: str | None = None
    mother_occupation: str | None = None
    mother_contact_no: str | None = None
    mother_email: str | None = None
    guardian_name: str | None = None
    guardian_relation: str | None = None
    guardian_contact_no: str | None = None
    emergency_contact_name: str | None = None
    emergency_contact_phone: str | None = None
    transport_required: bool | None = None
    bus_opted: bool | None = None
