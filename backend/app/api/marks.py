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
