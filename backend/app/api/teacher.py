from uuid import UUID
from typing import Any
import logging
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel

from datetime import date, timedelta

from app.core.database import get_db
from app.core.auth import require_teacher
from app.models import User, Branch, Class, Student, BranchAssignment, MarksCard, Attendance, ParentStudentLink
from app.services.chat_event_service import post_event_message

router = APIRouter(prefix="/teacher", tags=["teacher"])

logger = logging.getLogger(__name__)


def _teacher_class_id(user: User, db: Session) -> UUID | None:
    a = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    return a.class_id if a else None


def _student_in_teacher_class(student_id: UUID, class_id: UUID | None, db: Session) -> bool:
    if not class_id:
        return False
    s = db.query(Student).filter(Student.id == student_id, Student.class_id == class_id).first()
    return s is not None


def _teacher_classes_payload(user: User, db: Session) -> list[dict]:
    """All branch/class assignments for this teacher."""
    assignments = (
        db.query(BranchAssignment)
        .filter(
            BranchAssignment.user_id == user.id,
            BranchAssignment.class_id.isnot(None),
        )
        .all()
    )
    result = []
    for a in assignments:
        cls = db.query(Class).filter(Class.id == a.class_id).first()
        branch = db.query(Branch).filter(Branch.id == a.branch_id).first()
        if not cls:
            continue
        result.append({
            "class_id": str(cls.id),
            "class_name": cls.name,
            "branch_id": str(a.branch_id),
            "branch_name": branch.name if branch else None,
        })
    return result


@router.get("/classes")
def list_my_classes(
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """List all classes assigned to this teacher."""
    return {"classes": _teacher_classes_payload(user, db)}


@router.get("/dashboard")
def get_dashboard(
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Get teacher dashboard data: branch, class, students count."""
    classes = _teacher_classes_payload(user, db)
    assignment = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    branch_name = None
    class_name = None
    class_id = None
    students_count = 0
    boys_count = 0
    girls_count = 0

    if classes:
        class_id = classes[0]["class_id"]
        class_name = classes[0]["class_name"]
        branch_name = classes[0]["branch_name"]
    elif assignment:
        branch = db.query(Branch).filter(Branch.id == assignment.branch_id).first()
        if branch:
            branch_name = branch.name

    if class_id:
        students = db.query(Student).filter(
            Student.class_id == class_id,
            Student.admission_number.isnot(None),
        ).all()
        students_count = len(students)
        boys_count = sum(1 for s in students if s.gender and s.gender.lower() in ("male", "m", "boy"))
        girls_count = sum(1 for s in students if s.gender and s.gender.lower() in ("female", "f", "girl"))

    attendance_today = 0
    if class_id:
        present = db.query(Attendance).join(Student).filter(
            Student.class_id == class_id,
            Attendance.date == date.today(),
            Attendance.status == "present",
        ).count()
        attendance_today = present

    return {
        "branch_name": branch_name,
        "class_id": class_id,
        "class_name": class_name,
        "classes": classes,
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
    academic_year: str = "2026-27"
    data: dict[str, Any] = {}


@router.get("/marks/{student_id}")
def get_marks(
    student_id: UUID,
    academic_year: str = "2026-27",
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
    academic_year: str = "2026-27",
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
                staff_user_id=user.id,
                sender_id=user.id,
                student_id=student_id,
                body=event_body,
                send_push=True,
                push_title="Marks card sent",
            )
        except Exception:
            logger.exception(
                "Failed to append marks-sent event into chat",
                extra={"student_id": str(student_id), "teacher_id": str(user.id), "parent_id": str(parent_id)},
            )

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
    
    # Extract academic_year and data from request body
    academic_year = body.academic_year if body.academic_year else "2026-27"
    marks_data = body.data if body.data else {}
    
    card = db.query(MarksCard).filter(
        MarksCard.student_id == student_id, 
        MarksCard.academic_year == academic_year
    ).first()
    
    if card:
        card.data = marks_data
        db.commit()
        db.refresh(card)
    else:
        card = MarksCard(student_id=student_id, academic_year=academic_year, data=marks_data)
        db.add(card)
        db.commit()
        db.refresh(card)
    
    return {
        "id": str(card.id), 
        "student_id": str(card.student_id), 
        "academic_year": card.academic_year, 
        "data": card.data,
        "status": "success",
        "message": "Marks saved successfully"
    }


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
    from datetime import date as date_class
    from datetime import timedelta
    
    class_id = _teacher_class_id(user, db)
    if not class_id:
        return {"date": att_date.isoformat(), "locked": False, "records": []}
    
    # Check if date is in the past or already submitted
    today = date_class.today()
    is_past = att_date < today
    
    students = db.query(Student).filter(
        Student.class_id == class_id,
        Student.admission_number.isnot(None),
    ).order_by(Student.name).all()
    
    att_map = {a.student_id: a for a in db.query(Attendance).filter(
        Attendance.date == att_date,
        Attendance.student_id.in_([s.id for s in students]),
    ).all()}
    
    # Check if any record for this date is submitted
    submitted_count = sum(1 for a in att_map.values() if a.submitted)
    is_submitted = submitted_count > 0
    is_locked = is_submitted or is_past
    
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
    return {"date": att_date.isoformat(), "locked": is_locked, "records": result}


@router.put("/attendance")
def upsert_attendance(
    body: AttendanceUpsert,
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Mark attendance for teacher's class on a given date. Locks attendance once submitted."""
    from datetime import date as date_class
    
    class_id = _teacher_class_id(user, db)
    if not class_id:
        raise HTTPException(status_code=400, detail="No class assigned")
    
    # Prevent editing past days
    today = date_class.today()
    if body.date < today:
        raise HTTPException(status_code=400, detail="Cannot edit attendance for past dates")
    
    # Check if attendance for this date is already submitted
    existing_records = db.query(Attendance).filter(
        Attendance.date == body.date,
        Attendance.student_id.in_([UUID(rec.student_id) for rec in body.records])
    ).all()
    
    if any(a.submitted for a in existing_records):
        raise HTTPException(status_code=400, detail="Attendance for this date is already submitted and locked")
    
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
            existing.submitted = True  # Mark as submitted
        else:
            db.add(Attendance(student_id=sid, date=body.date, status=status, marked_by=user.id, submitted=True))
    db.commit()
    return {"date": body.date.isoformat(), "count": len(body.records), "locked": True}


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


@router.get("/parents/search")
def search_parents(
    phone: str = Query(..., description="Phone number to search for"),
    user: User = Depends(require_teacher),
    db: Session = Depends(get_db),
):
    """Search parents by student name, parent name, or phone."""
    def _norm_phone(value: str | None) -> str:
        digits = ''.join(ch for ch in (value or '') if ch.isdigit())
        return digits[-10:] if len(digits) >= 10 else digits

    term = (phone or "").strip()
    if len(term) < 3:
        return []

    # Match by parent contact info directly.
    users = db.query(User).filter(
        User.role == "parent",
        (
            User.phone.ilike(f"%{term}%")
            | User.full_name.ilike(f"%{term}%")
        ),
    ).all()

    # Also match parents through students whose name matches the query.
    matched_students = db.query(Student).filter(Student.name.ilike(f"%{term}%")).all()
    fallback_student_names_by_user: dict[str, set[str]] = {}
    for s in matched_students:
        for link in s.parent_links:
            if link.user and link.user.role == "parent":
                users.append(link.user)
                uid = str(link.user.id)
                fallback_student_names_by_user.setdefault(uid, set()).add(s.name)

    # Fallback for older records where parent_student_links may be missing.
    # Try to resolve parent users by stored student contact numbers.
    contact_numbers = set()
    for s in matched_students:
        for number in [s.father_contact_no, s.mother_contact_no, s.residential_contact_no]:
            if number:
                contact_numbers.add(number.strip())
    normalized_contacts = {_norm_phone(n) for n in contact_numbers if _norm_phone(n)}
    if normalized_contacts:
        fallback_users = db.query(User).filter(User.role == "parent").all()
        for u in fallback_users:
            user_phone = _norm_phone(u.phone)
            if not user_phone or user_phone not in normalized_contacts:
                continue
            users.append(u)
            uid = str(u.id)
            for s in matched_students:
                student_numbers = {
                    _norm_phone(s.father_contact_no),
                    _norm_phone(s.mother_contact_no),
                    _norm_phone(s.residential_contact_no),
                }
                if user_phone in student_numbers:
                    fallback_student_names_by_user.setdefault(uid, set()).add(s.name)

    deduped: dict[str, User] = {}
    for u in users:
        deduped[str(u.id)] = u

    results = []
    for u in deduped.values():
        students = {link.student.name for link in u.student_links if link.student}
        students.update(fallback_student_names_by_user.get(str(u.id), set()))
        results.append(
            {
                "id": str(u.id),
                "full_name": u.full_name,
                "phone": u.phone,
                "email": u.email,
                "students": sorted(students),
            }
        )
    return results
