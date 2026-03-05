from datetime import date
from pydantic import BaseModel
from uuid import UUID


class AdmissionCreate(BaseModel):
    enquiry_id: UUID
    branch_id: UUID
    class_id: UUID
    # Child - from enquiry, can override
    name: str
    date_of_birth: date
    gender: str | None = None
    place_of_birth: str | None = None
    nationality: str | None = None
    mother_tongue: str | None = None
    blood_group: str | None = None
    medical_allergies: str | None = None
    medical_surgeries: str | None = None
    medical_chronic_illness: str | None = None
    residential_address: str | None = None
    residential_contact_no: str | None = None
    # Previous school
    attended_previously: bool = False
    school_daycare_name: str | None = None
    prev_school_duration: str | None = None
    prev_school_class: str | None = None
    # Documents
    birth_certificate: bool = False
    immunization_record: bool = False
    transfer_certificate: bool = False
    passport_photos: bool = False
    progress_report: bool = False
    passport: bool = False
    other_medical_report: bool = False
    # Parent/Guardian
    parent_name: str  # Full name of parent who will login
    parent_contact: str | None = None  # Phone/email for parent
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
    transport_required: bool = False
    religion: str | None = None
