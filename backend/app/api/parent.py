from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timedelta

from app.core.database import get_db
from app.core.auth import require_parent
from app.models import User, Student, MarksCard, ParentStudentLink, Branch, Class, Attendance, FeeStructure, FeePayment

router = APIRouter(prefix="/parent", tags=["parent"])


@router.get("/children")
def get_my_children(
    user: User = Depends(require_parent),
    db: Session = Depends(get_db),
):
    """Get all children linked to the parent with their details."""
    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == user.id).all()
    student_ids = [l.student_id for l in links]
    if not student_ids:
        return {"children": []}
    
    students = db.query(Student).filter(Student.id.in_(student_ids)).all()
    result = []
    for s in students:
        branch_name = None
        class_name = None
        if s.branch_id:
            b = db.query(Branch).filter(Branch.id == s.branch_id).first()
            branch_name = b.name if b else None
        if s.class_id:
            c = db.query(Class).filter(Class.id == s.class_id).first()
            class_name = c.name if c else None
        result.append({
            "id": str(s.id),
            "name": s.name,
            "admission_number": s.admission_number,
            "date_of_birth": s.date_of_birth.isoformat() if s.date_of_birth else None,
            "branch_id": str(s.branch_id) if s.branch_id else None,
            "branch_name": branch_name,
            "class_id": str(s.class_id) if s.class_id else None,
            "class_name": class_name,
            "bus_opted": s.bus_opted or False,
        })
    return {"children": result}


@router.get("/marks-cards")
def get_my_children_marks_cards(
    user: User = Depends(require_parent),
    db: Session = Depends(get_db),
):
    """Get marks cards sent to parent for all linked children. Only returns cards with sent_to_parent_at set."""
    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == user.id).all()
    student_ids = [l.student_id for l in links]
    if not student_ids:
        return {"marks_cards": []}
    cards = (
        db.query(MarksCard)
        .filter(
            MarksCard.student_id.in_(student_ids),
            MarksCard.sent_to_parent_at.isnot(None),
        )
        .order_by(MarksCard.sent_to_parent_at.desc())
        .all()
    )
    result = []
    for card in cards:
        s = db.query(Student).filter(Student.id == card.student_id).first()
        if not s:
            continue
        branch_name = None
        class_name = None
        if s.branch_id:
            b = db.query(Branch).filter(Branch.id == s.branch_id).first()
            branch_name = b.name if b else None
        if s.class_id:
            c = db.query(Class).filter(Class.id == s.class_id).first()
            class_name = c.name if c else None
        result.append({
            "id": str(card.id),
            "student_id": str(card.student_id),
            "student_name": s.name,
            "admission_number": s.admission_number,
            "branch_name": branch_name,
            "class_name": class_name,
            "academic_year": card.academic_year,
            "data": card.data or {},
            "father_name": s.father_name,
            "mother_name": s.mother_name,
            "date_of_birth": s.date_of_birth.isoformat() if s.date_of_birth else None,
            "sent_at": card.sent_to_parent_at.isoformat() if card.sent_to_parent_at else None,
        })
    return {"marks_cards": result}


@router.get("/student/{student_id}/attendance")
def get_student_attendance(
    student_id: UUID,
    days: int = 30,
    user: User = Depends(require_parent),
    db: Session = Depends(get_db),
):
    """Get attendance records for a specific student for the last N days."""
    # Verify this student is linked to the parent
    link = db.query(ParentStudentLink).filter(
        ParentStudentLink.user_id == user.id,
        ParentStudentLink.student_id == student_id,
    ).first()
    
    if not link:
        raise HTTPException(status_code=403, detail="This student is not linked to you")
    
    # Get student details
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Get attendance records for the last N days
    cutoff_date = datetime.now().date() - timedelta(days=days)
    attendance_records = db.query(Attendance).filter(
        Attendance.student_id == student_id,
        Attendance.date >= cutoff_date,
    ).order_by(Attendance.date.desc()).all()
    
    # Calculate statistics
    present = sum(1 for a in attendance_records if a.status == "present")
    absent = sum(1 for a in attendance_records if a.status == "absent")
    leave = sum(1 for a in attendance_records if a.status == "leave")
    total = len(attendance_records)
    attendance_percentage = round((present / total * 100) if total > 0 else 0, 1)
    
    return {
        "student_id": str(student.id),
        "student_name": student.name,
        "admission_number": student.admission_number,
        "total_days": total,
        "present": present,
        "absent": absent,
        "leave": leave,
        "attendance_percentage": attendance_percentage,
        "records": [
            {
                "date": a.date.isoformat(),
                "status": a.status,
            }
            for a in attendance_records
        ],
    }


@router.get("/student/{student_id}/fees")
def get_student_fees(
    student_id: UUID,
    user: User = Depends(require_parent),
    db: Session = Depends(get_db),
):
    """Get fee structure and payment history for a specific student."""
    # Verify this student is linked to the parent
    link = db.query(ParentStudentLink).filter(
        ParentStudentLink.user_id == user.id,
        ParentStudentLink.student_id == student_id,
    ).first()
    
    if not link:
        raise HTTPException(status_code=403, detail="This student is not linked to you")
    
    # Get student details
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Get fee structure
    fee_struct = db.query(FeeStructure).filter(FeeStructure.student_id == student_id).first()
    
    if not fee_struct:
        return {
            "student_id": str(student.id),
            "student_name": student.name,
            "admission_number": student.admission_number,
            "advance_fees": 0.0,
            "term_fee_1": 0.0,
            "term_fee_2": 0.0,
            "term_fee_3": 0.0,
            "total_due": 0.0,
            "advance_fees_paid": 0.0,
            "term_fee_1_paid": 0.0,
            "term_fee_2_paid": 0.0,
            "term_fee_3_paid": 0.0,
            "total_paid": 0.0,
            "advance_fees_balance": 0.0,
            "term_fee_1_balance": 0.0,
            "term_fee_2_balance": 0.0,
            "term_fee_3_balance": 0.0,
            "total_balance": 0.0,
            "payments": [],
        }
    
    # Get all payments for this student
    payments = db.query(FeePayment).filter(FeePayment.student_id == student_id).all()
    
    # Calculate paid amounts per component
    paid_amounts = {}
    for payment in payments:
        if payment.component not in paid_amounts:
            paid_amounts[payment.component] = 0.0
        paid_amounts[payment.component] += payment.amount_paid
    
    # Calculate balances
    advance_fees_paid = paid_amounts.get("advance_fees", 0.0)
    term_fee_1_paid = paid_amounts.get("term_fee_1", 0.0)
    term_fee_2_paid = paid_amounts.get("term_fee_2", 0.0)
    term_fee_3_paid = paid_amounts.get("term_fee_3", 0.0)
    total_paid = sum(paid_amounts.values())
    
    total_due = fee_struct.advance_fees + fee_struct.term_fee_1 + fee_struct.term_fee_2 + fee_struct.term_fee_3
    advance_fees_balance = fee_struct.advance_fees - advance_fees_paid
    term_fee_1_balance = fee_struct.term_fee_1 - term_fee_1_paid
    term_fee_2_balance = fee_struct.term_fee_2 - term_fee_2_paid
    term_fee_3_balance = fee_struct.term_fee_3 - term_fee_3_paid
    total_balance = total_due - total_paid
    
    return {
        "student_id": str(student.id),
        "student_name": student.name,
        "admission_number": student.admission_number,
        "advance_fees": fee_struct.advance_fees,
        "term_fee_1": fee_struct.term_fee_1,
        "term_fee_2": fee_struct.term_fee_2,
        "term_fee_3": fee_struct.term_fee_3,
        "total_due": total_due,
        "advance_fees_paid": advance_fees_paid,
        "term_fee_1_paid": term_fee_1_paid,
        "term_fee_2_paid": term_fee_2_paid,
        "term_fee_3_paid": term_fee_3_paid,
        "total_paid": total_paid,
        "advance_fees_balance": advance_fees_balance,
        "term_fee_1_balance": term_fee_1_balance,
        "term_fee_2_balance": term_fee_2_balance,
        "term_fee_3_balance": term_fee_3_balance,
        "total_balance": total_balance,
        "payments": [
            {
                "id": str(p.id),
                "component": p.component,
                "amount_paid": p.amount_paid,
                "payment_mode": p.payment_mode,
                "payment_date": p.payment_date.isoformat() if p.payment_date else None,
            }
            for p in payments
        ],
    }