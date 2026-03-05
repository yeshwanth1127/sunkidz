from uuid import UUID
from datetime import date, timedelta
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.core.auth import require_coordinator
from app.models import User, Branch, Class, Student, BranchAssignment, Attendance, StaffAttendance, Enquiry
from app.schemas.student import StudentUpdate
from app.schemas.enquiry import EnquiryCreate

router = APIRouter(prefix="/coordinator", tags=["coordinator"])


def _coordinator_branch_id(user: User, db: Session) -> UUID | None:
    a = db.query(BranchAssignment).filter(
        BranchAssignment.user_id == user.id,
        BranchAssignment.class_id.is_(None),
    ).first()
    return a.branch_id if a else None


@router.get("/dashboard")
def get_dashboard(
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Get coordinator dashboard data for assigned branch."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        return {
            "branch_id": None,
            "branch_name": None,
            "students_count": 0,
            "teachers_count": 0,
            "attendance_today": 0,
            "weekly_attendance": [],
            "classes": [],
        }
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    students_count = db.query(func.count(Student.id)).filter(
        Student.branch_id == branch_id,
        Student.admission_number.isnot(None),
    ).scalar() or 0
    teachers_count = (
        db.query(func.count(BranchAssignment.id))
        .join(User)
        .filter(
            BranchAssignment.branch_id == branch_id,
            User.role == "teacher",
        )
        .scalar()
        or 0
    )
    students = db.query(Student).filter(
        Student.branch_id == branch_id,
        Student.admission_number.isnot(None),
    ).all()
    student_ids = [s.id for s in students]
    attendance_today = 0
    if student_ids:
        attendance_today = db.query(Attendance).filter(
            Attendance.student_id.in_(student_ids),
            Attendance.date == date.today(),
            Attendance.status == "present",
        ).count()
    weekly_attendance = []
    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    collected = 0
    i = 0
    while collected < 5 and i < 14:
        d = date.today() - timedelta(days=i)
        if d.weekday() < 5:
            total = len(student_ids)
            present = 0
            if student_ids:
                present = db.query(Attendance).filter(
                    Attendance.student_id.in_(student_ids),
                    Attendance.date == d,
                    Attendance.status == "present",
                ).count()
            pct = (present / total * 100) if total > 0 else 0
            weekly_attendance.append({
                "date": d.isoformat(),
                "day": day_names[d.weekday()],
                "present": present,
                "total": total,
                "pct": round(pct, 1),
            })
            collected += 1
        i += 1
    weekly_attendance.reverse()
    classes = db.query(Class).filter(Class.branch_id == branch_id).all()
    return {
        "branch_id": str(branch_id),
        "branch_name": branch.name if branch else None,
        "students_count": students_count,
        "teachers_count": teachers_count,
        "attendance_today": attendance_today,
        "weekly_attendance": weekly_attendance,
        "classes": [{"id": str(c.id), "name": c.name} for c in classes],
    }


@router.get("/teachers")
def list_teachers(
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """List teachers assigned to coordinator's branch."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        return []
    assignments = (
        db.query(BranchAssignment)
        .join(BranchAssignment.user)
        .filter(
            BranchAssignment.branch_id == branch_id,
            User.role == "teacher",
        )
        .all()
    )
    result = []
    for a in assignments:
        cls_name = None
        if a.class_id:
            c = db.query(Class).filter(Class.id == a.class_id).first()
            cls_name = c.name if c else None
        result.append({
            "id": str(a.user_id),
            "full_name": a.user.full_name,
            "email": a.user.email,
            "phone": a.user.phone,
            "class_id": str(a.class_id) if a.class_id else None,
            "class_name": cls_name,
        })
    return result


@router.get("/students/{student_id}")
def get_student(
    student_id: UUID,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Get full student profile. Student must be in coordinator's branch."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        raise HTTPException(status_code=403, detail="No branch assigned")
    s = db.query(Student).filter(
        Student.id == student_id,
        Student.branch_id == branch_id,
        Student.admission_number.isnot(None),
    ).first()
    if not s:
        raise HTTPException(status_code=404, detail="Student not found")
    branch_name = None
    class_name = None
    if s.branch_id:
        branch = db.query(Branch).filter(Branch.id == s.branch_id).first()
        branch_name = branch.name if branch else None
    if s.class_id:
        c = db.query(Class).filter(Class.id == s.class_id).first()
        class_name = c.name if c else None
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
        "place_of_birth": s.place_of_birth,
        "nationality": s.nationality,
        "religion": s.religion,
        "mother_tongue": s.mother_tongue,
        "blood_group": s.blood_group,
        "medical_allergies": s.medical_allergies,
        "medical_surgeries": s.medical_surgeries,
        "medical_chronic_illness": s.medical_chronic_illness,
        "branch_id": str(s.branch_id) if s.branch_id else None,
        "branch_name": branch_name,
        "class_id": str(s.class_id) if s.class_id else None,
        "class_name": class_name,
        "residential_address": s.residential_address,
        "residential_contact_no": s.residential_contact_no,
        "father_name": s.father_name,
        "father_occupation": s.father_occupation,
        "father_contact_no": s.father_contact_no,
        "father_email": s.father_email,
        "mother_name": s.mother_name,
        "mother_occupation": s.mother_occupation,
        "mother_contact_no": s.mother_contact_no,
        "mother_email": s.mother_email,
        "guardian_name": s.guardian_name,
        "guardian_relation": s.guardian_relation,
        "guardian_contact_no": s.guardian_contact_no,
        "emergency_contact_name": s.emergency_contact_name,
        "emergency_contact_phone": s.emergency_contact_phone,
        "parent_name": parent_name or s.father_name or s.mother_name,
        "parent_phone": parent_phone or s.father_contact_no or s.mother_contact_no or s.residential_contact_no,
        "transport_required": s.transport_required,
        "declaration_date": s.declaration_date.isoformat() if s.declaration_date else None,
    }


@router.put("/students/{student_id}")
def update_student(
    student_id: UUID,
    body: StudentUpdate,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Update student details. Student must be in coordinator's branch."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        raise HTTPException(status_code=403, detail="No branch assigned")
    s = db.query(Student).filter(
        Student.id == student_id,
        Student.branch_id == branch_id,
        Student.admission_number.isnot(None),
    ).first()
    if not s:
        raise HTTPException(status_code=404, detail="Student not found")
    data = body.model_dump(exclude_unset=True)
    if "date_of_birth" in data:
        dob = data["date_of_birth"]
        today = date.today()
        s.age_years = today.year - dob.year
        if (today.month, today.day) < (dob.month, dob.day):
            s.age_years -= 1
        s.age_months = s.age_years * 12 + (today.month - dob.month)
    if "class_id" in data and data["class_id"]:
        cls = db.query(Class).filter(Class.id == data["class_id"], Class.branch_id == branch_id).first()
        if not cls:
            raise HTTPException(status_code=400, detail="Class not found or not in this branch")
    for k, v in data.items():
        setattr(s, k, v)
    db.commit()
    db.refresh(s)
    branch_name = None
    class_name = None
    if s.branch_id:
        branch = db.query(Branch).filter(Branch.id == s.branch_id).first()
        branch_name = branch.name if branch else None
    if s.class_id:
        c = db.query(Class).filter(Class.id == s.class_id).first()
        class_name = c.name if c else None
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
        "place_of_birth": s.place_of_birth,
        "nationality": s.nationality,
        "religion": s.religion,
        "mother_tongue": s.mother_tongue,
        "blood_group": s.blood_group,
        "medical_allergies": s.medical_allergies,
        "medical_surgeries": s.medical_surgeries,
        "medical_chronic_illness": s.medical_chronic_illness,
        "branch_id": str(s.branch_id) if s.branch_id else None,
        "branch_name": branch_name,
        "class_id": str(s.class_id) if s.class_id else None,
        "class_name": class_name,
        "residential_address": s.residential_address,
        "residential_contact_no": s.residential_contact_no,
        "father_name": s.father_name,
        "father_occupation": s.father_occupation,
        "father_contact_no": s.father_contact_no,
        "father_email": s.father_email,
        "mother_name": s.mother_name,
        "mother_occupation": s.mother_occupation,
        "mother_contact_no": s.mother_contact_no,
        "mother_email": s.mother_email,
        "guardian_name": s.guardian_name,
        "guardian_relation": s.guardian_relation,
        "guardian_contact_no": s.guardian_contact_no,
        "emergency_contact_name": s.emergency_contact_name,
        "emergency_contact_phone": s.emergency_contact_phone,
        "parent_name": parent_name or s.father_name or s.mother_name,
        "parent_phone": parent_phone or s.father_contact_no or s.mother_contact_no or s.residential_contact_no,
        "transport_required": s.transport_required,
        "declaration_date": s.declaration_date.isoformat() if s.declaration_date else None,
    }


@router.get("/students")
def list_students(
    class_id: UUID | None = None,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """List students in coordinator's branch. Optional class_id filter."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        return []
    q = db.query(Student).filter(
        Student.branch_id == branch_id,
        Student.admission_number.isnot(None),
    )
    if class_id:
        q = q.filter(Student.class_id == class_id)
    students = q.order_by(Student.class_id, Student.name).all()
    result = []
    for s in students:
        cls_name = None
        if s.class_id:
            c = db.query(Class).filter(Class.id == s.class_id).first()
            cls_name = c.name if c else None
        result.append({
            "id": str(s.id),
            "admission_number": s.admission_number,
            "name": s.name,
            "date_of_birth": s.date_of_birth.isoformat() if s.date_of_birth else None,
            "age_years": s.age_years,
            "age_months": s.age_months,
            "gender": s.gender,
            "class_id": str(s.class_id) if s.class_id else None,
            "class_name": cls_name,
        })
    return result


@router.get("/attendance")
def get_attendance(
    att_date: date,
    class_id: UUID | None = None,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Get attendance for coordinator's branch. Optional class_id to filter by class."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        return {"date": att_date.isoformat(), "by_class": {}}
    q = db.query(Student).filter(
        Student.branch_id == branch_id,
        Student.admission_number.isnot(None),
    )
    if class_id:
        q = q.filter(Student.class_id == class_id)
    students = q.order_by(Student.class_id, Student.name).all()
    student_ids = [s.id for s in students]
    att_map = {a.student_id: a for a in db.query(Attendance).filter(
        Attendance.date == att_date,
        Attendance.student_id.in_(student_ids),
    ).all()}
    by_class: dict[str, list] = {}
    for s in students:
        cls_name = "—"
        if s.class_id:
            c = db.query(Class).filter(Class.id == s.class_id).first()
            cls_name = c.name if c else "—"
        if cls_name not in by_class:
            by_class[cls_name] = []
        a = att_map.get(s.id)
        by_class[cls_name].append({
            "id": str(s.id),
            "admission_number": s.admission_number,
            "name": s.name,
            "status": a.status if a else "present",
        })
    return {"date": att_date.isoformat(), "branch_id": str(branch_id), "by_class": by_class}


@router.get("/attendance/history")
def get_attendance_history(
    period: str = "week",
    class_id: UUID | None = None,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Get attendance history for coordinator's branch. period=week or month."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        return {"period": period, "dates": [], "by_date": {}, "by_class": {}}
    q = db.query(Student).filter(
        Student.branch_id == branch_id,
        Student.admission_number.isnot(None),
    )
    if class_id:
        q = q.filter(Student.class_id == class_id)
    students = q.all()
    student_ids = [s.id for s in students]
    end_d = date.today()
    start_d = end_d - timedelta(days=7 if period == "week" else 30)
    atts = db.query(Attendance).filter(
        Attendance.student_id.in_(student_ids),
        Attendance.date >= start_d,
        Attendance.date <= end_d,
    ).all()
    by_date: dict[str, list] = {}
    by_class: dict[str, dict] = {}
    for s in students:
        cls_name = "—"
        if s.class_id:
            c = db.query(Class).filter(Class.id == s.class_id).first()
            cls_name = c.name if c else "—"
        if cls_name not in by_class:
            by_class[cls_name] = {"students": {}, "dates": []}
        by_class[cls_name]["students"][str(s.id)] = {"name": s.name, "admission_number": s.admission_number, "dates": {}}
    for a in atts:
        dk = a.date.isoformat()
        if dk not in by_date:
            by_date[dk] = []
        by_date[dk].append({"student_id": str(a.student_id), "status": a.status})
        for cls_data in by_class.values():
            if str(a.student_id) in cls_data["students"]:
                cls_data["students"][str(a.student_id)]["dates"][dk] = a.status
    dates = sorted(by_date.keys())
    return {"period": period, "start": start_d.isoformat(), "end": end_d.isoformat(), "dates": dates, "by_date": by_date, "by_class": by_class}


# --- Staff (Teacher) Attendance ---
class StaffAttendanceRecord(BaseModel):
    user_id: str
    status: str  # present, absent, leave


class StaffAttendanceUpsert(BaseModel):
    date: date
    records: list[StaffAttendanceRecord]


def _staff_attendance_response(att_date: date, branch_id: UUID, db: Session) -> dict:
    assignments = (
        db.query(BranchAssignment)
        .join(BranchAssignment.user)
        .filter(
            BranchAssignment.branch_id == branch_id,
            User.role == "teacher",
        )
        .all()
    )
    user_ids = [a.user_id for a in assignments]
    att_map = {a.user_id: a for a in db.query(StaffAttendance).filter(
        StaffAttendance.date == att_date,
        StaffAttendance.user_id.in_(user_ids),
    ).all()}
    result = []
    for a in assignments:
        att = att_map.get(a.user_id)
        cls_name = None
        if a.class_id:
            c = db.query(Class).filter(Class.id == a.class_id).first()
            cls_name = c.name if c else None
        result.append({
            "user_id": str(a.user_id),
            "full_name": a.user.full_name,
            "email": a.user.email,
            "class_name": cls_name,
            "status": att.status if att else "present",
        })
    return {"date": att_date.isoformat(), "branch_id": str(branch_id), "staff": result}


@router.get("/staff-attendance")
def get_staff_attendance(
    att_date: date,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Get staff attendance for coordinator's branch on a given date."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        return {"date": att_date.isoformat(), "staff": []}
    return _staff_attendance_response(att_date, branch_id, db)


@router.put("/staff-attendance")
def upsert_staff_attendance(
    body: StaffAttendanceUpsert,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Mark staff attendance for coordinator's branch on a given date."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        raise HTTPException(status_code=403, detail="No branch assigned")
    assignments = (
        db.query(BranchAssignment)
        .join(BranchAssignment.user)
        .filter(
            BranchAssignment.branch_id == branch_id,
            User.role == "teacher",
        )
        .all()
    )
    allowed_ids = {a.user_id for a in assignments}
    for rec in body.records:
        uid = UUID(rec.user_id)
        if uid not in allowed_ids:
            raise HTTPException(status_code=403, detail=f"User {rec.user_id} not in your branch")
        status = rec.status if rec.status in ("present", "absent", "leave") else "present"
        existing = db.query(StaffAttendance).filter(
            StaffAttendance.user_id == uid,
            StaffAttendance.date == body.date,
        ).first()
        if existing:
            existing.status = status
            existing.marked_by = user.id
        else:
            db.add(StaffAttendance(user_id=uid, date=body.date, status=status, marked_by=user.id))
    db.commit()
    return _staff_attendance_response(body.date, branch_id, db)


@router.get("/staff-attendance/history")
def get_staff_attendance_history(
    period: str = "week",
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Get staff attendance history for coordinator's branch. period=week or month."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        return {"period": period, "dates": [], "by_date": {}, "by_staff": {}}
    assignments = (
        db.query(BranchAssignment)
        .join(BranchAssignment.user)
        .filter(
            BranchAssignment.branch_id == branch_id,
            User.role == "teacher",
        )
        .all()
    )
    user_ids = [a.user_id for a in assignments]
    end_d = date.today()
    start_d = end_d - timedelta(days=7 if period == "week" else 30)
    atts = db.query(StaffAttendance).filter(
        StaffAttendance.user_id.in_(user_ids),
        StaffAttendance.date >= start_d,
        StaffAttendance.date <= end_d,
    ).all()
    by_date: dict[str, list] = {}
    by_staff: dict[str, dict] = {}
    for a in assignments:
        by_staff[str(a.user_id)] = {"name": a.user.full_name, "class_name": None, "dates": {}}
        if a.class_id:
            c = db.query(Class).filter(Class.id == a.class_id).first()
            by_staff[str(a.user_id)]["class_name"] = c.name if c else None
    for att in atts:
        dk = att.date.isoformat()
        if dk not in by_date:
            by_date[dk] = []
        by_date[dk].append({"user_id": str(att.user_id), "status": att.status})
        if str(att.user_id) in by_staff:
            by_staff[str(att.user_id)]["dates"][dk] = att.status
    dates = sorted(by_date.keys())
    return {"period": period, "start": start_d.isoformat(), "end": end_d.isoformat(), "dates": dates, "by_date": by_date, "by_staff": by_staff}


@router.get("/enquiries")
def get_enquiries(
    status: str | None = None,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Get enquiries for coordinator's branch. Optional status filter."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        return []
    q = db.query(Enquiry).filter(Enquiry.branch_id == branch_id)
    if status:
        q = q.filter(Enquiry.status == status)
    enquiries = q.order_by(Enquiry.created_at.desc()).all()
    result = []
    for e in enquiries:
        branch_name = None
        if e.branch_id:
            branch = db.query(Branch).filter(Branch.id == e.branch_id).first()
            branch_name = branch.name if branch else None
        result.append({
            "id": str(e.id),
            "child_name": e.child_name,
            "date_of_birth": e.date_of_birth.isoformat() if e.date_of_birth else None,
            "age_years": e.age_years,
            "age_months": e.age_months,
            "gender": e.gender,
            "father_name": e.father_name,
            "mother_name": e.mother_name,
            "father_contact_no": e.father_contact_no,
            "mother_contact_no": e.mother_contact_no,
            "residential_address": e.residential_address,
            "branch_id": str(e.branch_id) if e.branch_id else None,
            "branch_name": branch_name,
            "status": e.status or "pending",
            "created_at": e.created_at.isoformat() if e.created_at else None,
        })
    return result


@router.post("/enquiries")
def create_enquiry(
    data: EnquiryCreate,
    user: User = Depends(require_coordinator),
    db: Session = Depends(get_db),
):
    """Create enquiry for coordinator's branch. Coordinator must have a branch assigned."""
    branch_id = _coordinator_branch_id(user, db)
    if not branch_id:
        raise HTTPException(status_code=403, detail="No branch assigned")
    
    e = Enquiry(
        child_name=data.child_name,
        date_of_birth=data.date_of_birth,
        age_years=data.age_years,
        age_months=data.age_months,
        gender=data.gender,
        father_name=data.father_name,
        father_occupation=data.father_occupation,
        father_place_of_work=data.father_place_of_work,
        father_email=data.father_email,
        father_contact_no=data.father_contact_no,
        mother_name=data.mother_name,
        mother_occupation=data.mother_occupation,
        mother_place_of_work=data.mother_place_of_work,
        mother_email=data.mother_email,
        mother_contact_no=data.mother_contact_no,
        siblings_info=data.siblings_info,
        siblings_age=data.siblings_age,
        residential_address=data.residential_address,
        residential_contact_no=data.residential_contact_no,
        challenges_specialities=data.challenges_specialities,
        expectations_from_school=data.expectations_from_school,
        branch_id=branch_id,  # Always assign to coordinator's branch
        status=data.status or "pending",
    )
    db.add(e)
    db.commit()
    db.refresh(e)
    
    branch_name = None
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if branch:
        branch_name = branch.name
    
    return {
        "id": str(e.id),
        "child_name": e.child_name,
        "date_of_birth": e.date_of_birth.isoformat() if e.date_of_birth else None,
        "age_years": e.age_years,
        "age_months": e.age_months,
        "gender": e.gender,
        "father_name": e.father_name,
        "mother_name": e.mother_name,
        "father_contact_no": e.father_contact_no,
        "mother_contact_no": e.mother_contact_no,
        "residential_address": e.residential_address,
        "branch_id": str(e.branch_id) if e.branch_id else None,
        "branch_name": branch_name,
        "status": e.status or "pending",
        "created_at": e.created_at.isoformat() if e.created_at else None,
    }
