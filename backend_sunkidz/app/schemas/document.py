from datetime import date
from typing import Any
from uuid import UUID
from pydantic import BaseModel


class IngestionDocumentResponse(BaseModel):
    id: UUID
    branch_id: UUID
    branch_name: str | None = None
    doc_type: str
    status: str
    file_name: str
    file_mime: str | None = None
    file_size: str | None = None
    uploaded_by: UUID
    uploader_name: str | None = None
    raw_ocr_data: dict[str, Any] | None = None
    extracted_data: dict[str, Any] | None = None
    confidence_scores: dict[str, Any] | None = None
    matched_student_id: UUID | None = None
    matched_student_name: str | None = None
    matched_parent_user_id: UUID | None = None
    reviewed_by: UUID | None = None
    reviewed_at: str | None = None
    error_message: str | None = None
    created_at: str | None = None
    updated_at: str | None = None


class OcrResultIn(BaseModel):
    """Payload n8n PATCHes back to /documents/{id}/ocr-result after OCR/AI
    extraction. `status` must be "needs_review" (extraction succeeded, a
    human must confirm before it is applied) or "failed" (n8n gives up)."""
    raw_ocr_data: dict[str, Any] | None = None
    extracted_data: dict[str, Any] = {}
    confidence_scores: dict[str, Any] | None = None
    status: str = "needs_review"
    error_message: str | None = None


class DocumentApplyRequest(BaseModel):
    """Reviewer-confirmed admission data to write into Student / User /
    ParentStudentLink. Field set mirrors AdmissionDirectCreate so the same
    student record shape is produced whether admission comes from the manual
    form or from a digitized document."""

    mode: str  # "create_student" | "update_student"
    student_id: UUID | None = None  # required when mode == "update_student"

    # Skip the automatic duplicate check because the reviewer has already
    # confirmed, by eye, that a flagged candidate is NOT actually a match.
    force_new_student: bool = False
    force_new_parent: bool = False

    branch_id: UUID
    class_id: UUID

    name: str
    date_of_birth: date
    gender: str | None = None
    place_of_birth: str | None = None
    nationality: str | None = None
    mother_tongue: str | None = None
    religion: str | None = None
    blood_group: str | None = None
    medical_allergies: str | None = None
    medical_surgeries: str | None = None
    medical_chronic_illness: str | None = None
    residential_address: str | None = None
    residential_contact_no: str | None = None

    attended_previously: bool = False
    school_daycare_name: str | None = None
    prev_school_duration: str | None = None
    prev_school_class: str | None = None

    birth_certificate: bool = False
    immunization_record: bool = False
    transfer_certificate: bool = False
    passport_photos: bool = False
    progress_report: bool = False
    passport: bool = False
    other_medical_report: bool = False

    parent_user_id: UUID | None = None
    parent_name: str
    parent_contact: str | None = None
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


class DocumentRejectRequest(BaseModel):
    reason: str | None = None
