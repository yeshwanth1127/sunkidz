"""Admission-document ingestion: a teacher/admin/coordinator uploads a scanned
admission form (image or PDF) for a branch+class they already selected; an
external n8n workflow OCRs it and writes structured data back here. The
backend then automatically validates and applies it to the real Student /
User / ParentStudentLink records — no manual "review and click apply" step
in the normal path. A document only stops short of that (status="failed")
when required fields are missing or a likely-duplicate student/parent is
found; a human then fixes/confirms it via the same apply endpoint.

This table is a staging + audit layer only — n8n never writes to `students`
or `users` directly, it only ever updates a row here.
"""
import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class IngestionDocument(Base):
    __tablename__ = "ingestion_documents"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"), nullable=False)
    # Selected at upload time (same as the manual admission form) since OCR
    # cannot reliably infer which of a branch's classes a child belongs in.
    # Nullable only for rows created before this column existed.
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.id"), nullable=True)
    doc_type = Column(String(50), nullable=False, default="admission_form")

    # pending -> processing -> applied   (the normal, fully-automatic path)
    #                       -> failed    (missing fields / likely duplicate;
    #                                     needs a human to open the document
    #                                     and apply manually)
    #         -> rejected                (human explicitly discards it)
    status = Column(String(20), nullable=False, default="pending")

    file_path = Column(String(500), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_mime = Column(String(100), nullable=True)
    file_size = Column(String(50), nullable=True)

    uploaded_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Unedited OCR/AI output, kept for audit even after a reviewer corrects it.
    raw_ocr_data = Column(JSONB, nullable=True)
    # Structured admission fields extracted by n8n (reviewer-editable in the UI).
    extracted_data = Column(JSONB, nullable=True)
    # Optional per-field OCR confidence (0-1) so the review UI can flag
    # low-confidence fields.
    confidence_scores = Column(JSONB, nullable=True)

    matched_student_id = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=True)
    matched_parent_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)

    reviewed_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)

    error_message = Column(Text, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    uploader = relationship("User", foreign_keys=[uploaded_by])
    matched_student = relationship("Student", foreign_keys=[matched_student_id])
    matched_parent = relationship("User", foreign_keys=[matched_parent_user_id])
    reviewer = relationship("User", foreign_keys=[reviewed_by])
