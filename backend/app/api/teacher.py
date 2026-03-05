from uuid import UUID
from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from datetime import date, timedelta

from app.core.database import get_db
from app.core.auth import require_teacher
from app.models import User, Branch, Class, Student, BranchAssignment, MarksCard, Attendance

router = APIRouter(prefix="/teacher", tags=["teacher"])


def _teacher_class_id(user: User, db: Session) -> UUID | None:
    a = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    return a.class_id if a else None


def _student_in_teacher_class(student_id: UUID, class_id: UUID | None, db: Session) -> bool:
    if not class_id:
        return False
    s = db.query(Student).filter(Student.id == student_id, Student.class_id == class_id).first()
    return s is not None


@router.get("/dashboard")
def get_dashboard(
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Get teacher dashboard data: branch, class, students count."""
    assignment = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    branch_name = None
    class_name = None
    students_count = 0
    boys_count = 0
    girls_count = 0

    if assignment:
        branch = db.query(Branch).filter(Branch.id == assignment.branch_id).first()
        if branch:
            branch_name = branch.name
        if assignment.class_id:
            cls = db.query(Class).filter(Class.id == assignment.class_id).first()
            if cls:
                class_name = cls.name
            # Count students in this class
            students = db.query(Student).filter(
                Student.class_id == assignment.class_id,
                Student.admission_number.isnot(None),
            ).all()
            students_count = len(students)
            boys_count = sum(1 for s in students if s.gender and s.gender.lower() in ("male", "m", "boy"))
            girls_count = sum(1 for s in students if s.gender and s.gender.lower() in ("female", "f", "girl"))

    attendance_today = 0
    if assignment and assignment.class_id:
        present = db.query(Attendance).join(Student).filter(
            Student.class_id == assignment.class_id,
            Attendance.date == date.today(),
            Attendance.status == "present",
        ).count()
        attendance_today = present

    return {
        "branch_name": branch_name,
        "class_name": class_name,
        "students_count": students_count,
        "boys_count": boys_count,
        "girls_count": girls_count,
        "attendance_today": attendance_today,
    }


@router.get("/students")
def list_my_students(
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """List students in teacher's assigned class."""
    assignment = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    if not assignment or not assignment.class_id:
        return []
    students = (
        db.query(Student)
        .filter(
            Student.class_id == assignment.class_id,
            Student.admission_number.isnot(None),
        )
        .order_by(Student.name)
        .all()
    )
    result = []
    for s in students:
        branch_name = None
        class_name = None
        if s.branch_id:
            branch = db.query(Branch).filter(Branch.id == s.branch_id).first()
            branch_name = branch.name if branch else None
        if s.class_id:
            cls = db.query(Class).filter(Class.id == s.class_id).first()
            class_name = cls.name if cls else None
        result.append({
            "id": str(s.id),
            "admission_number": s.admission_number,
            "name": s.name,
            "date_of_birth": s.date_of_birth.isoformat() if s.date_of_birth else None,
            "age_years": s.age_years,
            "age_months": s.age_months,
            "gender": s.gender,
            "branch_id": str(s.branch_id) if s.branch_id else None,
            "branch_name": branch_name,
            "class_id": str(s.class_id) if s.class_id else None,
            "class_name": class_name,
        })
    return result


@router.get("/students/{student_id}")
def get_student(
    student_id: UUID,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Get student profile (only if in teacher's class)."""
    class_id = _teacher_class_id(user, db)
    if not _student_in_teacher_class(student_id, class_id, db):
        raise HTTPException(status_code=404, detail="Student not found in your class")
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Student not found")
    branch_name = None
    class_name = None
    if s.branch_id:
        branch = db.query(Branch).filter(Branch.id == s.branch_id).first()
        branch_name = branch.name if branch else None
    if s.class_id:
        cls = db.query(Class).filter(Class.id == s.class_id).first()
        class_name = cls.name if cls else None
    parent_name = None
    parent_phone = None
    if s.parent_links:
        try:
            parent_name = s.parent_links[0].user.full_name
            parent_phone = s.parent_links[0].user.phone
        except Exception:
            pass
    return {
        "id": str(s.id),
        "admission_number": s.admission_number,
        "name": s.name,
        "date_of_birth": s.date_of_birth.isoformat() if s.date_of_birth else None,
        "age_years": s.age_years,
        "age_months": s.age_months,
        "gender": s.gender,
        "branch_id": str(s.branch_id) if s.branch_id else None,
        "branch_name": branch_name,
        "class_id": str(s.class_id) if s.class_id else None,
        "class_name": class_name,
        "residential_address": s.residential_address,
        "father_name": s.father_name,
        "mother_name": s.mother_name,
        "parent_name": parent_name or s.father_name or s.mother_name,
        "parent_phone": parent_phone or s.father_contact_no or s.mother_contact_no or s.residential_contact_no,
        "declaration_date": s.declaration_date.isoformat() if s.declaration_date else None,
    }


class MarksCardUpsert(BaseModel):
    academic_year: str = "2024-25"
    data: dict[str, Any] = {}


@router.get("/marks/{student_id}")
def get_marks(
    student_id: UUID,
    academic_year: str = "2024-25",
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Get marks for a student in teacher's class."""
    class_id = _teacher_class_id(user, db)
    if not _student_in_teacher_class(student_id, class_id, db):
        raise HTTPException(status_code=404, detail="Student not found in your class")
    card = db.query(MarksCard).filter(MarksCard.student_id == student_id, MarksCard.academic_year == academic_year).first()
    if not card:
        return {"student_id": str(student_id), "academic_year": academic_year, "data": None, "sent_to_parent_at": None}
    return {
        "id": str(card.id),
        "student_id": str(card.student_id),
        "academic_year": card.academic_year,
        "data": card.data,
        "sent_to_parent_at": card.sent_to_parent_at.isoformat() if card.sent_to_parent_at else None,
    }


@router.post("/marks/{student_id}/send-to-parent")
def send_marks_to_parent(
    student_id: UUID,
    academic_year: str = "2024-25",
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Mark marks card as sent to parent."""
    class_id = _teacher_class_id(user, db)
    if not _student_in_teacher_class(student_id, class_id, db):
        raise HTTPException(status_code=404, detail="Student not found in your class")
    card = db.query(MarksCard).filter(MarksCard.student_id == student_id, MarksCard.academic_year == academic_year).first()
    if not card:
        raise HTTPException(status_code=404, detail="Marks card not found")
    from datetime import datetime, timezone
    card.sent_to_parent_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(card)
    return {
        "id": str(card.id),
        "student_id": str(card.student_id),
        "academic_year": card.academic_year,
        "sent_to_parent_at": card.sent_to_parent_at.isoformat(),
    }


@router.put("/marks/{student_id}")
def upsert_marks(
    student_id: UUID,
    body: MarksCardUpsert,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Update marks for a student in teacher's class."""
    class_id = _teacher_class_id(user, db)
    if not _student_in_teacher_class(student_id, class_id, db):
        raise HTTPException(status_code=404, detail="Student not found in your class")
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    card = db.query(MarksCard).filter(MarksCard.student_id == student_id, MarksCard.academic_year == body.academic_year).first()
    if card:
        card.data = body.data
    else:
        card = MarksCard(student_id=student_id, academic_year=body.academic_year, data=body.data)
        db.add(card)
    db.commit()
    db.refresh(card)
    return {"id": str(card.id), "student_id": str(card.student_id), "academic_year": card.academic_year, "data": card.data}


# --- Attendance ---

@router.get("/attendance/students")
def list_attendance_students(
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """List students in teacher's class for attendance marking."""
    return list_my_students(user=user, db=db)


class AttendanceRecord(BaseModel):
    student_id: str
    status: str  # present, absent, leave


class AttendanceUpsert(BaseModel):
    date: date
    records: list[AttendanceRecord]


@router.get("/attendance")
def get_attendance(
    att_date: date,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Get attendance for teacher's class on a given date."""
    class_id = _teacher_class_id(user, db)
    if not class_id:
        return {"date": att_date.isoformat(), "records": []}
    students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.admission_number.isnot(None),
    ).order_by(Student.name).all()
    att_map = {a.student_id: a for a in db.query(Attendance).filter(
        Attendance.date == att_date,
        Attendance.student_id.in_([s.id for s in students]),
    ).all()}
    result = []
    for s in students:
        a = att_map.get(s.id)
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
            "admission_number": s.admission_number,
            "name": s.name,
            "class_name": class_name,
            "branch_name": branch_name,
            "status": a.status if a else "present",
        })
    return {"date": att_date.isoformat(), "records": result}


@router.put("/attendance")
def upsert_attendance(
    body: AttendanceUpsert,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Mark attendance for teacher's class on a given date."""
    class_id = _teacher_class_id(user, db)
    if not class_id:
        raise HTTPException(status_code=400, detail="No class assigned")
    for rec in body.records:
        sid = UUID(rec.student_id)
        if not _student_in_teacher_class(sid, class_id, db):
            raise HTTPException(status_code=403, detail=f"Student {rec.student_id} not in your class")
        status = rec.status if rec.status in ("present", "absent", "leave") else "present"
        existing = db.query(Attendance).filter(
            Attendance.student_id == sid,
            Attendance.date == body.date,
        ).first()
        if existing:
            existing.status = status
            existing.marked_by = user.id
        else:
            db.add(Attendance(student_id=sid, date=body.date, status=status, marked_by=user.id))
    db.commit()
    return {"date": body.date.isoformat(), "count": len(body.records)}


@router.get("/attendance/history")
def get_attendance_history(
    period: str = "week",  # week or month
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Get attendance history for teacher's class. period=week or month."""
    class_id = _teacher_class_id(user, db)
    if not class_id:
        return {"period": period, "dates": [], "by_date": {}, "by_student": {}}
    students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.admission_number.isnot(None),
    ).order_by(Student.name).all()
    student_ids = [s.id for s in students]
    end_d = date.today()
    start_d = end_d - timedelta(days=7 if period == "week" else 30)
    atts = db.query(Attendance).filter(
        Attendance.student_id.in_(student_ids),
        Attendance.date >= start_d,
        Attendance.date <= end_d,
    ).all()
    by_date: dict[str, list] = {}
    by_student: dict[str, dict[str, str]] = {}
    for s in students:
        by_student[str(s.id)] = {"name": s.name, "admission_number": s.admission_number, "dates": {}}
    for a in atts:
        dk = a.date.isoformat()
        if dk not in by_date:
            by_date[dk] = []
        by_date[dk].append({"student_id": str(a.student_id), "status": a.status})
        if str(a.student_id) in by_student:
            by_student[str(a.student_id)]["dates"][dk] = a.status
    dates = sorted(by_date.keys())
    return {"period": period, "start": start_d.isoformat(), "end": end_d.isoformat(), "dates": dates, "by_date": by_date, "by_student": by_student}
