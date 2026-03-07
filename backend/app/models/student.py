import uuid
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Date, Integer, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class Student(Base):
    __tablename__ = "students"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    admission_number = Column(String(50), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    date_of_birth = Column(Date, nullable=False)
    age_years = Column(Integer, nullable=True)
    age_months = Column(Integer, nullable=True)
    gender = Column(String(20), nullable=True)
    place_of_birth = Column(String(255), nullable=True)
    nationality = Column(String(100), nullable=True)
    mother_tongue = Column(String(100), nullable=True)
    religion = Column(String(100), nullable=True)
    blood_group = Column(String(20), nullable=True)
    medical_allergies = Column(Text, nullable=True)
    medical_surgeries = Column(Text, nullable=True)
    medical_chronic_illness = Column(Text, nullable=True)
    class_id = Column(UUID(as_uuid=True), ForeignKey("classes.id"), nullable=True)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"), nullable=True)
    enquiry_id = Column(UUID(as_uuid=True), ForeignKey("enquiries.id"), nullable=True)
    photo_path = Column(String(500), nullable=True)
    residential_address = Column(Text, nullable=True)
    residential_contact_no = Column(String(50), nullable=True)
    father_name = Column(String(255), nullable=True)
    father_occupation = Column(String(255), nullable=True)
    father_contact_no = Column(String(50), nullable=True)
    father_email = Column(String(255), nullable=True)
    mother_name = Column(String(255), nullable=True)
    mother_occupation = Column(String(255), nullable=True)
    mother_contact_no = Column(String(50), nullable=True)
    mother_email = Column(String(255), nullable=True)
    guardian_name = Column(String(255), nullable=True)
    guardian_relation = Column(String(100), nullable=True)
    guardian_contact_no = Column(String(50), nullable=True)
    emergency_contact_name = Column(String(255), nullable=True)
    emergency_contact_phone = Column(String(50), nullable=True)
    transport_required = Column(Boolean, default=False)
    bus_opted = Column(Boolean, default=False)
    attended_previously = Column(Boolean, default=False)
    school_daycare_name = Column(String(255), nullable=True)
    prev_school_duration = Column(String(100), nullable=True)
    prev_school_class = Column(String(50), nullable=True)
    birth_certificate = Column(Boolean, default=False)
    immunization_record = Column(Boolean, default=False)
    transfer_certificate = Column(Boolean, default=False)
    passport_photos = Column(Boolean, default=False)
    progress_report = Column(Boolean, default=False)
    passport = Column(Boolean, default=False)
    other_medical_report = Column(Boolean, default=False)
    declaration_date = Column(Date, nullable=True)
    parent_signature_path = Column(String(500), nullable=True)
    office_date = Column(Date, nullable=True)
    school_rep_signature_path = Column(String(500), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    parent_links = relationship("ParentStudentLink", back_populates="student", lazy="selectin")
    fee_structure = relationship("FeeStructure", back_populates="student", uselist=False)


class ParentStudentLink(Base):
    __tablename__ = "parent_student_links"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id"), nullable=False)
    is_primary = Column(Boolean, default=True)

    user = relationship("User", back_populates="parent_links")
    student = relationship("Student", back_populates="parent_links")
