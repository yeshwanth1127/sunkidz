from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class FeePaymentCreate(BaseModel):
    component: str  # advance_fees, term_fee_1, term_fee_2, term_fee_3
    amount_paid: float
    payment_mode: str  # cash, upi, net_banking, cheque, bank_transfer


class FeePaymentResponse(BaseModel):
    id: str
    component: str
    amount_paid: float
    payment_mode: str
    payment_date: datetime
    created_at: datetime

    class Config:
        from_attributes = True


class FeeStructureCreate(BaseModel):
    advance_fees: float = 0.0
    term_fee_1: float = 0.0
    term_fee_2: float = 0.0
    term_fee_3: float = 0.0


class FeeStructureResponse(BaseModel):
    id: str
    student_id: str
    branch_id: str
    advance_fees: float
    term_fee_1: float
    term_fee_2: float
    term_fee_3: float
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class FeesDetailResponse(BaseModel):
    """Detailed fee information with calculations."""
    student_id: str
    student_name: str
    admission_number: str
    
    advance_fees: float
    term_fee_1: float
    term_fee_2: float
    term_fee_3: float
    total_due: float
    
    advance_fees_paid: float
    term_fee_1_paid: float
    term_fee_2_paid: float
    term_fee_3_paid: float
    total_paid: float
    
    advance_fees_balance: float
    term_fee_1_balance: float
    term_fee_2_balance: float
    term_fee_3_balance: float
    total_balance: float
    
    payments: list[FeePaymentResponse] = []


class FeesSavePaymentsRequest(BaseModel):
    payments: list[dict]  # [{component: str, amount_paid: float, payment_mode: str}, ...]
