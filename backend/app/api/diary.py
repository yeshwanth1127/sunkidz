from datetime import date
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import get_current_user, require_parent
from app.models.user import User
from app.models.branch import Class, Branch
from app.models.student import Student, ParentStudentLink
from app.models.class_diary import ClassDiaryEntry
from app.schemas.diary import (
    DiaryEntryCreate,
    DiaryEntryResponse,
    DiaryStudentItem,
)
from app.services.class_access import can_upload_to_class, can_view_class

router = APIRouter(prefix="/diary", tags=["diary"])


def _entry_response(db: Session, entry: ClassDiaryEntry) -> DiaryEntryResponse:
    author = db.query(User).filter(User.id == entry.author_id).first()
    cls = db.query(Class).filter(Class.id == entry.class_id).first()
    branch = db.query(Branch).filter(Branch.id == entry.branch_id).first()
    student = None
    if entry.student_id:
        student = db.query(Student).filter(Student.id == entry.student_id).first()
    return DiaryEntryResponse(
        id=str(entry.id),
        class_id=str(entry.class_id),
        branch_id=str(entry.branch_id),
        author_id=str(entry.author_id),
        author_name=author.full_name if author else None,
        class_name=cls.name if cls else None,
        branch_name=branch.name if branch else None,
        student_id=str(entry.student_id) if entry.student_id else None,
        student_name=student.name if student else None,
        entry_date=entry.entry_date.isoformat(),
        remarks=entry.remarks,
        activities=entry.activities,
        homework_notes=entry.homework_notes,
        created_at=entry.created_at.isoformat() if entry.created_at else None,
        updated_at=entry.updated_at.isoformat() if entry.updated_at else None,
    )


@router.get("/classes/{class_id}/students", response_model=List[DiaryStudentItem])
def list_class_students(
    class_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Students in a class — used by diary screens to attach per-student notes."""
    if not can_view_class(db, user, class_id):
        raise HTTPException(status_code=403, detail="No permission for this class")
    students = (
        db.query(Student)
        .filter(Student.class_id == class_id)
        .order_by(Student.name)
        .all()
    )
    return [
        DiaryStudentItem(
            id=str(s.id),
            name=s.name,
            admission_number=getattr(s, "admission_number", None),
        )
        for s in students
    ]


@router.post("/entries", response_model=DiaryEntryResponse)
def upsert_diary_entry(
    data: DiaryEntryCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if user.role not in ("admin", "teacher", "coordinator"):
        raise HTTPException(status_code=403, detail="Not allowed")
    if not can_upload_to_class(db, user, data.class_id):
        raise HTTPException(status_code=403, detail="No permission for this class")

    cls = db.query(Class).filter(Class.id == data.class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")

    if data.student_id:
        student = (
            db.query(Student)
            .filter(Student.id == data.student_id, Student.class_id == data.class_id)
            .first()
        )
        if not student:
            raise HTTPException(
                status_code=400,
                detail="Student is not in the selected class",
            )

    q = db.query(ClassDiaryEntry).filter(
        ClassDiaryEntry.class_id == data.class_id,
        ClassDiaryEntry.entry_date == data.entry_date,
    )
    if data.student_id:
        q = q.filter(ClassDiaryEntry.student_id == data.student_id)
    else:
        q = q.filter(ClassDiaryEntry.student_id.is_(None))
    entry = q.first()

    if entry:
        entry.remarks = data.remarks
        entry.activities = data.activities
        entry.homework_notes = data.homework_notes
        entry.author_id = user.id
    else:
        entry = ClassDiaryEntry(
            class_id=data.class_id,
            branch_id=cls.branch_id,
            student_id=data.student_id,
            author_id=user.id,
            entry_date=data.entry_date,
            remarks=data.remarks,
            activities=data.activities,
            homework_notes=data.homework_notes,
        )
        db.add(entry)
    db.commit()
    db.refresh(entry)
    return _entry_response(db, entry)


@router.delete("/entries/{entry_id}")
def delete_diary_entry(
    entry_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    entry = db.query(ClassDiaryEntry).filter(ClassDiaryEntry.id == entry_id).first()
    if not entry:
        raise HTTPException(status_code=404, detail="Entry not found")
    if not can_upload_to_class(db, user, entry.class_id):
        raise HTTPException(status_code=403, detail="No permission for this entry")
    db.delete(entry)
    db.commit()
    return {"ok": True}


@router.get("/entries", response_model=List[DiaryEntryResponse])
def list_diary_entries(
    class_id: UUID = Query(...),
    student_id: Optional[UUID] = Query(None),
    from_date: Optional[date] = Query(None),
    to_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if not can_view_class(db, user, class_id):
        raise HTTPException(status_code=403, detail="No permission for this class")

    q = db.query(ClassDiaryEntry).filter(ClassDiaryEntry.class_id == class_id)
    if student_id is not None:
        # Show that student's personal notes + class-wide entries (student_id NULL).
        q = q.filter(
            (ClassDiaryEntry.student_id == student_id)
            | (ClassDiaryEntry.student_id.is_(None))
        )
    if from_date:
        q = q.filter(ClassDiaryEntry.entry_date >= from_date)
    if to_date:
        q = q.filter(ClassDiaryEntry.entry_date <= to_date)
    entries = q.order_by(ClassDiaryEntry.entry_date.desc()).all()
    return [_entry_response(db, e) for e in entries]


@router.get("/parent/entries", response_model=List[DiaryEntryResponse])
def list_parent_diary_entries(
    from_date: Optional[date] = Query(None),
    to_date: Optional[date] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(require_parent),
):
    """Parent view: returns class-wide notes plus the parent's own children's
    personal notes (never another child's personal note)."""
    links = db.query(ParentStudentLink).filter(
        ParentStudentLink.user_id == user.id
    ).all()
    student_ids = [link.student_id for link in links]
    if not student_ids:
        return []

    children = db.query(Student).filter(Student.id.in_(student_ids)).all()
    class_ids = list({c.class_id for c in children if c.class_id})
    if not class_ids:
        return []

    q = db.query(ClassDiaryEntry).filter(
        ClassDiaryEntry.class_id.in_(class_ids),
        (
            ClassDiaryEntry.student_id.is_(None)
            | ClassDiaryEntry.student_id.in_(student_ids)
        ),
    )
    if from_date:
        q = q.filter(ClassDiaryEntry.entry_date >= from_date)
    if to_date:
        q = q.filter(ClassDiaryEntry.entry_date <= to_date)
    entries = q.order_by(ClassDiaryEntry.entry_date.desc()).all()
    return [_entry_response(db, e) for e in entries]
