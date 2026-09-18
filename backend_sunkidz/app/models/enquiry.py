import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Date, Integer, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class Enquiry(Base):
    __tablename__ = "enquiries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    child_name = Column(String(255), nullable=False)
    date_of_birth = Column(Date, nullable=True)
    age_years = Column(Integer, nullable=True)
    age_months = Column(Integer, nullable=True)
    gender = Column(String(20), nullable=True)
    father_name = Column(String(255), nullable=True)
    father_occupation = Column(String(255), nullable=True)
    father_place_of_work = Column(String(255), nullable=True)
    father_email = Column(String(255), nullable=True)
    father_contact_no = Column(String(50), nullable=True)
    mother_name = Column(String(255), nullable=True)
    mother_occupation = Column(String(255), nullable=True)
    mother_place_of_work = Column(String(255), nullable=True)
    mother_email = Column(String(255), nullable=True)
    mother_contact_no = Column(String(50), nullable=True)
    siblings_info = Column(Text, nullable=True)
    siblings_age = Column(String(100), nullable=True)
    residential_address = Column(Text, nullable=True)
    residential_contact_no = Column(String(50), nullable=True)
    challenges_specialities = Column(Text, nullable=True)
    expectations_from_school = Column(Text, nullable=True)
    signature_date = Column(Date, nullable=True)
    status = Column(String(50), default="pending")
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
