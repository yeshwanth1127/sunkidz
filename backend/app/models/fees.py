import uuid
from datetime import datetime
from sqlalchemy import Column, String, Float, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from app.core.database import Base


class FeeStructure(Base):
    """Fee structure per student. Defines the fee components and amounts."""
    __tablename__ = "fee_structures"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False, unique=True)
    branch_id = Column(UUID(as_uuid=True), ForeignKey("branches.id", ondelete="CASCADE"), nullable=False)
    
    advance_fees = Column(Float, default=0.0)
    term_fee_1 = Column(Float, default=0.0)
    term_fee_2 = Column(Float, default=0.0)
    term_fee_3 = Column(Float, default=0.0)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    student = relationship("Student", back_populates="fee_structure")
    payments = relationship("FeePayment", back_populates="fee_structure", cascade="all, delete-orphan")


class FeePayment(Base):
    """Payment records for student fees."""
    __tablename__ = "fee_payments"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    fee_structure_id = Column(UUID(as_uuid=True), ForeignKey("fee_structures.id", ondelete="CASCADE"), nullable=False)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    
    component = Column(String(50), nullable=False)  # advance_fees, term_fee_1, term_fee_2, term_fee_3
    amount_paid = Column(Float, nullable=False)
    payment_mode = Column(String(50), nullable=False)  # cash, upi, net_banking, cheque, bank_transfer
    
    payment_date = Column(DateTime, default=datetime.utcnow)
    marked_by = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    fee_structure = relationship("FeeStructure", back_populates="payments")
    student = relationship("Student")


class FeeReceipt(Base):
    """Receipt records pushed to a parent's dashboard by the admin."""
    __tablename__ = "fee_receipts"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    payment_id = Column(UUID(as_uuid=True), ForeignKey("fee_payments.id", ondelete="CASCADE"), nullable=False)

    # Snapshot of all data needed to render/download the receipt without re-querying
    student_name = Column(String(255), nullable=False)
    admission_number = Column(String(100), nullable=True)
    component = Column(String(50), nullable=False)
    component_label = Column(String(100), nullable=False)
    amount_paid = Column(Float, nullable=False)
    payment_mode = Column(String(50), nullable=False)
    payment_date = Column(DateTime, nullable=True)
    receipt_ref = Column(String(20), nullable=False)  # first 8 chars of payment UUID
    fee_data_json = Column(String(4000), nullable=True)  # JSON snapshot of fee summary

    created_at = Column(DateTime, default=datetime.utcnow)
