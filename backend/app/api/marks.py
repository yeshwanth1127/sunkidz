from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import require_admin
from app.models import User, Student, MarksCard
from app.schemas.marks import MarksCardUpsert

router = APIRouter(prefix="/admin/marks", tags=["marks"])


@router.get("/{student_id}")
def get_marks(
    student_id: UUID,
    academic_year: str = "2024-25",
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get marks card for a student."""
    card = (
        db.query(MarksCard)
        .filter(MarksCard.student_id == student_id, MarksCard.academic_year == academic_year)
        .first()
    )
    if not card:
        return {"student_id": str(student_id), "academic_year": academic_year, "data": None, "sent_to_parent_at": None}
    return {
        "id": str(card.id),
        "student_id": str(card.student_id),
        "academic_year": card.academic_year,
        "data": card.data,
        "sent_to_parent_at": card.sent_to_parent_at.isoformat() if card.sent_to_parent_at else None,
    }


@router.put("/{student_id}")
def upsert_marks(
    student_id: UUID,
    body: MarksCardUpsert,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    academic_year = body.academic_year
    data = body.data
    """Create or update marks card for a student."""
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    card = (
        db.query(MarksCard)
        .filter(MarksCard.student_id == student_id, MarksCard.academic_year == academic_year)
        .first()
    )
    if card:
        card.data = data
    else:
        card = MarksCard(student_id=student_id, academic_year=academic_year, data=data)
        db.add(card)
    db.commit()
    db.refresh(card)
    return {
        "id": str(card.id),
        "student_id": str(card.student_id),
        "academic_year": card.academic_year,
        "data": card.data,
        "sent_to_parent_at": card.sent_to_parent_at.isoformat() if card.sent_to_parent_at else None,
    }


@router.post("/{student_id}/send-to-parent")
def send_marks_to_parent(
    student_id: UUID,
    academic_year: str = Query("2024-25"),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Mark marks card as sent to parent. Parent will see it in their dashboard."""
    card = (
        db.query(MarksCard)
        .filter(MarksCard.student_id == student_id, MarksCard.academic_year == academic_year)
        .first()
    )
    if not card:
        raise HTTPException(status_code=404, detail="Marks card not found")
    from datetime import datetime, timezone
    card.sent_to_parent_at = datetime.now(timezone.utc)  # noqa: F811
    db.commit()
    db.refresh(card)
    return {
        "id": str(card.id),
        "student_id": str(card.student_id),
        "academic_year": card.academic_year,
        "sent_to_parent_at": card.sent_to_parent_at.isoformat(),
    }


@router.get("/class/{class_id}/summary")
def get_class_marks_summary(
    class_id: UUID,
    academic_year: str = "2024-25",
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get marks summary for all students in a class."""
    from app.models import Class, Student
    
    # Verify class exists
    cls = db.query(Class).filter(Class.id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")
    
    # Get all students in this class
    students = db.query(Student).filter(Student.class_id == class_id).all()
    
    marks_data = []
    for student in students:
        card = db.query(MarksCard).filter(
            MarksCard.student_id == student.id,
            MarksCard.academic_year == academic_year
        ).first()
        
        marks_data.append({
            "student_id": str(student.id),
            "student_name": student.name,
            "admission_number": student.admission_number,
            "has_marks": card is not None,
            "marks_data": card.data if card else None,
            "sent_to_parent_at": card.sent_to_parent_at.isoformat() if card and card.sent_to_parent_at else None,
        })
    
    return {
        "class_id": str(class_id),
        "class_name": cls.name,
        "academic_year": academic_year,
        "total_students": len(students),
        "students_with_marks": sum(1 for m in marks_data if m["has_marks"]),
        "marks": marks_data,
    }


@router.get("/branch/{branch_id}/summary")
def get_branch_marks_summary(
    branch_id: UUID,
    academic_year: str = "2024-25",
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get marks summary for all students in a branch."""
    from app.models import Branch, Class
    
    # Verify branch exists
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    
    # Get all students in this branch
    students = db.query(Student).filter(Student.branch_id == branch_id).all()
    
    marks_data = []
    for student in students:
        card = db.query(MarksCard).filter(
            MarksCard.student_id == student.id,
            MarksCard.academic_year == academic_year
        ).first()
        
        class_name = None
        if student.class_id:
            cls = db.query(Class).filter(Class.id == student.class_id).first()
            class_name = cls.name if cls else None
        
        marks_data.append({
            "student_id": str(student.id),
            "student_name": student.name,
            "admission_number": student.admission_number,
            "class_name": class_name,
            "has_marks": card is not None,
            "marks_data": card.data if card else None,
            "sent_to_parent_at": card.sent_to_parent_at.isoformat() if card and card.sent_to_parent_at else None,
        })
    
    return {
        "branch_id": str(branch_id),
        "branch_name": branch.name,
        "academic_year": academic_year,
        "total_students": len(students),
        "students_with_marks": sum(1 for m in marks_data if m["has_marks"]),
        "marks": marks_data,
    }
