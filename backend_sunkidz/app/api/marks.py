from uuid import UUID
import logging
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import require_admin
from app.models import User, Student, MarksCard, ParentStudentLink
from app.schemas.marks import MarksCardUpsert
from app.services.chat_event_service import post_event_message
from app.services.marks_card import (
    latest_marks_card,
    latest_marks_card_pruning_duplicates,
    preserve_signatures,
    save_marks_signature,
)

router = APIRouter(prefix="/admin/marks", tags=["marks"])

logger = logging.getLogger(__name__)


@router.get("/{student_id}")
def get_marks(
    student_id: UUID,
    academic_year: str = "2026-27",
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get the current marks card for a student (the single latest version)."""
    card = latest_marks_card(db, student_id, academic_year)
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
    """Create or update the single current marks card for a student.

    Always writes the one latest row (older duplicates, if any exist, are
    pruned) so every subsequent save / send / read sees this same version.
    """
    academic_year = body.academic_year
    data = body.data
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    card = latest_marks_card_pruning_duplicates(db, student_id, academic_year)
    if card:
        card.data = preserve_signatures(card.data, data)
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


@router.post("/{student_id}/signature")
async def upload_marks_signature(
    student_id: UUID,
    role: str = Form(...),
    academic_year: str = Form("2026-27"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Upload / replace a signature image (Parent, Class Teacher or Principal)
    on the student's one current marks card."""
    content = await file.read()
    return save_marks_signature(
        db, student_id, academic_year, role, file.filename, content
    )


@router.post("/{student_id}/send-to-parent")
def send_marks_to_parent(
    student_id: UUID,
    academic_year: str = Query("2026-27"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """Send the current marks card to the parent.

    Operates on the single latest saved row and stamps it as sent, so the
    version the parent loads is always the most recently saved one. Re-sending
    after another edit simply re-stamps that same row — no new record, no stale
    copy.
    """
    card = latest_marks_card_pruning_duplicates(db, student_id, academic_year)
    if not card:
        raise HTTPException(status_code=404, detail="Marks card not found")
    from datetime import datetime, timezone
    card.sent_to_parent_at = datetime.now(timezone.utc)  # noqa: F811
    db.commit()
    db.refresh(card)

    student = db.query(Student).filter(Student.id == student_id).first()
    parent_links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student_id).all()
    parent_ids = {link.user_id for link in parent_links}
    event_body = (
        f"[Marks Card Sent] Marks card for {student.name if student else 'your child'} "
        f"({academic_year}) is now available in the app."
    )
    for parent_id in parent_ids:
        try:
            post_event_message(
                db,
                parent_user_id=parent_id,
                staff_user_id=current_user.id,
                sender_id=current_user.id,
                student_id=student_id,
                body=event_body,
                send_push=True,
                push_title="Marks card sent",
            )
        except Exception:
            logger.exception(
                "Failed to append marks-sent event into chat",
                extra={"student_id": str(student_id), "admin_id": str(current_user.id), "parent_id": str(parent_id)},
            )

    return {
        "id": str(card.id),
        "student_id": str(card.student_id),
        "academic_year": card.academic_year,
        "sent_to_parent_at": card.sent_to_parent_at.isoformat(),
    }


@router.get("/class/{class_id}/summary")
def get_class_marks_summary(
    class_id: UUID,
    academic_year: str = "2026-27",
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
        card = latest_marks_card(db, student.id, academic_year)

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
    academic_year: str = "2026-27",
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
        card = latest_marks_card(db, student.id, academic_year)

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
