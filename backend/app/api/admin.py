from uuid import UUID
from datetime import date, timedelta
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from pydantic import BaseModel

from app.core.database import get_db
from app.core.auth import get_current_user, require_admin
from app.core.config import settings
from app.core.security import get_password_hash
from app.models.user import User
from app.models.branch import Branch, Class, BranchAssignment
from app.models.student import Student
from app.models.attendance import Attendance
from app.models.fees import FeeStructure, FeePayment
from app.models.marks_card import MarksCard
from app.models.enquiry import Enquiry
from app.schemas.admin import (
    BranchCreate,
    BranchUpdate,
    BranchResponse,
    ClassCreate,
    ClassUpdate,
    ClassResponse,
    UserCreate,
    UserUpdate,
    UserResponse,
    AssignmentCreate,
    AssignmentUpdate,
    AssignmentResponse,
)
from app.schemas.fee import (
    FeeStructureCreate,
    FeeStructureResponse,
    FeePaymentCreate,
    FeePaymentResponse,
    FeesDetailResponse,
)

router = APIRouter(prefix="/admin", tags=["admin"])


def _ensure_branch_classes(db: Session, branch_id: UUID) -> None:
    """Create default classes for a branch if missing."""
    for name in settings.default_branch_classes:
        if not db.query(Class).filter(Class.branch_id == branch_id, Class.name == name).first():
            db.add(Class(branch_id=branch_id, name=name, academic_year="2024-25"))
    db.commit()


# --- Branches ---
@router.get("/branches", response_model=list[BranchResponse])
def list_branches(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    branches = db.query(Branch).all()
    result = []
    for b in branches:
        coord = next(
            (a for a in b.assignments if a.user.role == "coordinator" and a.class_id is None),
            None,
        )
        student_count = db.query(func.count(Student.id)).filter(Student.branch_id == b.id).scalar() or 0
        result.append(
            BranchResponse(
                id=str(b.id),
                name=b.name,
                address=b.address,
                contact_no=b.contact_no,
                status=b.status,
                classes=[ClassResponse(id=str(c.id), branch_id=str(c.branch_id), name=c.name, academic_year=c.academic_year) for c in b.classes],
                coordinator_name=coord.user.full_name if coord else None,
                student_count=student_count,
            )
        )
    return result


@router.post("/branches", response_model=BranchResponse)
def create_branch(
    data: BranchCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    branch = Branch(
        name=data.name,
        code=data.code,
        address=data.address,
        contact_no=data.contact_no,
        status=data.status,
    )
    db.add(branch)
    db.commit()
    db.refresh(branch)
    _ensure_branch_classes(db, branch.id)
    db.refresh(branch)
    return BranchResponse(
        id=str(branch.id),
        name=branch.name,
        address=branch.address,
        contact_no=branch.contact_no,
        status=branch.status,
        classes=[ClassResponse(id=str(c.id), branch_id=str(c.branch_id), name=c.name, academic_year=c.academic_year) for c in branch.classes],
    )


@router.get("/branches/{branch_id}", response_model=BranchResponse)
def get_branch(
    branch_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    coord = next((a for a in branch.assignments if a.user.role == "coordinator" and a.class_id is None), None)
    student_count = db.query(func.count(Student.id)).filter(Student.branch_id == branch.id).scalar() or 0
    return BranchResponse(
        id=str(branch.id),
        name=branch.name,
        address=branch.address,
        contact_no=branch.contact_no,
        status=branch.status,
        classes=[ClassResponse(id=str(c.id), branch_id=str(c.branch_id), name=c.name, academic_year=c.academic_year) for c in branch.classes],
        coordinator_name=coord.user.full_name if coord else None,
        student_count=student_count,
    )


@router.put("/branches/{branch_id}", response_model=BranchResponse)
def update_branch(
    branch_id: UUID,
    data: BranchUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    if data.name is not None:
        branch.name = data.name
    if data.code is not None:
        branch.code = data.code
    if data.address is not None:
        branch.address = data.address
    if data.contact_no is not None:
        branch.contact_no = data.contact_no
    if data.status is not None:
        branch.status = data.status
    db.commit()
    db.refresh(branch)
    coord = next((a for a in branch.assignments if a.user.role == "coordinator" and a.class_id is None), None)
    student_count = db.query(func.count(Student.id)).filter(Student.branch_id == branch.id).scalar() or 0
    return BranchResponse(
        id=str(branch.id),
        name=branch.name,
        address=branch.address,
        contact_no=branch.contact_no,
        status=branch.status,
        classes=[ClassResponse(id=str(c.id), branch_id=str(c.branch_id), name=c.name, academic_year=c.academic_year) for c in branch.classes],
        coordinator_name=coord.user.full_name if coord else None,
        student_count=student_count,
    )


# --- Classes (Grades) ---
@router.get("/classes", response_model=list[ClassResponse])
def list_classes(
    branch_id: UUID | None = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    q = db.query(Class)
    if branch_id:
        q = q.filter(Class.branch_id == branch_id)
    classes = q.all()
    return [ClassResponse(id=str(c.id), branch_id=str(c.branch_id), name=c.name, academic_year=c.academic_year) for c in classes]


@router.post("/classes", response_model=ClassResponse)
def create_class(
    data: ClassCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    branch = db.query(Branch).filter(Branch.id == data.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    existing = db.query(Class).filter(Class.branch_id == data.branch_id, Class.name == data.name).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Class '{data.name}' already exists in this branch")
    cls = Class(
        branch_id=data.branch_id,
        name=data.name,
        academic_year=data.academic_year or "2024-25",
    )
    db.add(cls)
    db.commit()
    db.refresh(cls)
    return ClassResponse(id=str(cls.id), branch_id=str(cls.branch_id), name=cls.name, academic_year=cls.academic_year)


@router.put("/classes/{class_id}", response_model=ClassResponse)
def update_class(
    class_id: UUID,
    data: ClassUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    cls = db.query(Class).filter(Class.id == class_id).first()
    if not cls:
        raise HTTPException(status_code=404, detail="Class not found")
    if data.name is not None:
        cls.name = data.name
    if data.academic_year is not None:
        cls.academic_year = data.academic_year
    db.commit()
    db.refresh(cls)
    return ClassResponse(id=str(cls.id), branch_id=str(cls.branch_id), name=cls.name, academic_year=cls.academic_year)


# --- Users (Teachers, Coordinators, Bus Staff) ---
@router.get("/users", response_model=list[UserResponse])
def list_users(
    role: str | None = Query(None, description="teacher, coordinator, bus_staff"),
    branch_id: UUID | None = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    q = db.query(User).filter(User.role.in_(["teacher", "coordinator", "bus_staff"]))
    if role:
        q = q.filter(User.role == role)
    users = q.all()
    result = []
    for u in users:
        a = db.query(BranchAssignment).filter(BranchAssignment.user_id == u.id).first()
        branch = a.branch if a else None
        cls = a.class_ if a and a.class_id else None
        if branch_id and (not a or a.branch_id != branch_id):
            continue
        result.append(
            UserResponse(
                id=str(u.id),
                email=u.email,
                full_name=u.full_name,
                role=u.role,
                phone=u.phone,
                is_active=u.is_active,
                branch_id=str(a.branch_id) if a else None,
                branch_name=branch.name if branch else None,
                class_id=str(a.class_id) if a and a.class_id else None,
                class_name=cls.name if cls else None,
            )
        )
    return result


@router.post("/users", response_model=UserResponse)
def create_user(
    data: UserCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    if data.role not in ("teacher", "coordinator", "bus_staff"):
        raise HTTPException(status_code=400, detail="Role must be teacher, coordinator, or bus_staff")
    if data.email and db.query(User).filter(User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    user = User(
        email=data.email,
        password_hash=get_password_hash(data.password),
        full_name=data.full_name,
        role=data.role,
        phone=data.phone,
        is_active="true",
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return UserResponse(
        id=str(user.id),
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        phone=user.phone,
        is_active=user.is_active,
    )


@router.delete("/users/{user_id}")
def delete_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Delete a staff member (teacher/coordinator/bus_staff). Cannot delete admin."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role == "admin":
        raise HTTPException(status_code=403, detail="Cannot delete admin")
    if user.role not in ("teacher", "coordinator", "bus_staff"):
        raise HTTPException(status_code=403, detail="Can only delete teachers, coordinators, and bus staff")
    # Delete branch assignments first
    db.query(BranchAssignment).filter(BranchAssignment.user_id == user_id).delete()
    db.delete(user)
    db.commit()
    return {"ok": True}


@router.put("/users/{user_id}", response_model=UserResponse)
def update_user(
    user_id: UUID,
    data: UserUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role == "admin":
        raise HTTPException(status_code=403, detail="Cannot modify admin")
    if data.email is not None:
        existing = db.query(User).filter(User.email == data.email, User.id != user_id).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already in use")
        user.email = data.email
    if data.full_name is not None:
        user.full_name = data.full_name
    if data.phone is not None:
        user.phone = data.phone
    if data.is_active is not None:
        user.is_active = data.is_active
    db.commit()
    db.refresh(user)
    a = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    branch = a.branch if a else None
    cls = a.class_ if a and a.class_id else None
    return UserResponse(
        id=str(user.id),
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        phone=user.phone,
        is_active=user.is_active,
        branch_id=str(a.branch_id) if a else None,
        branch_name=branch.name if branch else None,
        class_id=str(a.class_id) if a and a.class_id else None,
        class_name=cls.name if cls else None,
    )


# --- Admissions / Students (list students from converted enquiries) ---
@router.get("/admissions")
def list_admissions(
    branch_id: UUID | None = Query(None),
    class_id: UUID | None = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """List all students (admissions). Filter by branch and/or class (grade)."""
    q = db.query(Student).filter(Student.admission_number.isnot(None))
    if branch_id:
        q = q.filter(Student.branch_id == branch_id)
    if class_id:
        q = q.filter(Student.class_id == class_id)
    students = q.order_by(Student.created_at.desc()).all()
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
        parent_contact = s.residential_contact_no
        if s.parent_links:
            try:
                parent_contact = s.parent_links[0].user.phone or parent_contact
            except Exception:
                pass
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
            "father_name": s.father_name,
            "mother_name": s.mother_name,
            "parent_contact": parent_contact,
            "bus_opted": s.bus_opted or False,
        })
    return result


@router.post("/students/{student_id}/toggle-bus-opt")
def toggle_bus_opt(
    student_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Toggle the bus opt-in status for a student."""
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    student.bus_opted = not (student.bus_opted or False)
    db.commit()
    db.refresh(student)
    
    return {"ok": True, "bus_opted": student.bus_opted}


@router.delete("/students/{student_id}")
def delete_student(
    student_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Delete a student. Removes parent_links, marks_cards, attendances first."""
    from app.models.student import ParentStudentLink
    from app.models.marks_card import MarksCard
    from app.models.attendance import Attendance

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student_id).delete()
    db.query(MarksCard).filter(MarksCard.student_id == student_id).delete()
    db.query(Attendance).filter(Attendance.student_id == student_id).delete()
    db.delete(student)
    db.commit()
    return {"ok": True}


# --- Assignments (Reassign teachers/coordinators) ---
@router.get("/assignments", response_model=list[AssignmentResponse])
def list_assignments(
    branch_id: UUID | None = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    q = db.query(BranchAssignment).join(User).filter(User.role.in_(["teacher", "coordinator"]))
    if branch_id:
        q = q.filter(BranchAssignment.branch_id == branch_id)
    assignments = q.all()
    return [
        AssignmentResponse(
            id=str(a.id),
            user_id=str(a.user_id),
            user_name=a.user.full_name,
            user_role=a.user.role,
            branch_id=str(a.branch_id),
            branch_name=a.branch.name,
            class_id=str(a.class_id) if a.class_id else None,
            class_name=a.class_.name if a.class_ else None,
        )
        for a in assignments
    ]


@router.post("/assignments", response_model=AssignmentResponse)
def create_assignment(
    data: AssignmentCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    user = db.query(User).filter(User.id == data.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role not in ("teacher", "coordinator"):
        raise HTTPException(status_code=400, detail="User must be teacher or coordinator")
    branch = db.query(Branch).filter(Branch.id == data.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    if user.role == "coordinator" and data.class_id:
        raise HTTPException(status_code=400, detail="Coordinators are not assigned to classes")
    if user.role == "teacher" and data.class_id:
        cls = db.query(Class).filter(Class.id == data.class_id, Class.branch_id == data.branch_id).first()
        if not cls:
            raise HTTPException(status_code=400, detail="Class not found or not in this branch")
    # Remove existing assignment for this user
    existing = db.query(BranchAssignment).filter(BranchAssignment.user_id == data.user_id).first()
    if existing:
        db.delete(existing)
        db.commit()
    a = BranchAssignment(
        user_id=data.user_id,
        branch_id=data.branch_id,
        class_id=data.class_id if user.role == "teacher" else None,
    )
    db.add(a)
    db.commit()
    db.refresh(a)
    return AssignmentResponse(
        id=str(a.id),
        user_id=str(a.user_id),
        user_name=a.user.full_name,
        user_role=a.user.role,
        branch_id=str(a.branch_id),
        branch_name=a.branch.name,
        class_id=str(a.class_id) if a.class_id else None,
        class_name=a.class_.name if a.class_ else None,
    )


@router.put("/assignments/{assignment_id}", response_model=AssignmentResponse)
def update_assignment(
    assignment_id: UUID,
    data: AssignmentUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    a = db.query(BranchAssignment).filter(BranchAssignment.id == assignment_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="Assignment not found")
    if data.branch_id is not None:
        branch = db.query(Branch).filter(Branch.id == data.branch_id).first()
        if not branch:
            raise HTTPException(status_code=404, detail="Branch not found")
        a.branch_id = data.branch_id
        if a.user.role == "coordinator":
            a.class_id = None
        elif data.class_id is None:
            a.class_id = None
    if data.class_id is not None and a.user.role == "teacher":
        cls = db.query(Class).filter(Class.id == data.class_id, Class.branch_id == a.branch_id).first()
        if not cls:
            raise HTTPException(status_code=400, detail="Class not found or not in this branch")
        a.class_id = data.class_id
    db.commit()
    db.refresh(a)
    return AssignmentResponse(
        id=str(a.id),
        user_id=str(a.user_id),
        user_name=a.user.full_name,
        user_role=a.user.role,
        branch_id=str(a.branch_id),
        branch_name=a.branch.name,
        class_id=str(a.class_id) if a.class_id else None,
        class_name=a.class_.name if a.class_ else None,
    )


@router.delete("/assignments/{assignment_id}")
def delete_assignment(
    assignment_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    a = db.query(BranchAssignment).filter(BranchAssignment.id == assignment_id).first()
    if not a:
        raise HTTPException(status_code=404, detail="Assignment not found")
    db.delete(a)
    db.commit()
    return {"ok": True}


# --- Admin Attendance ---

@router.get("/attendance")
def get_attendance(
    att_date: date,
    branch_id: UUID | None = None,
    class_id: UUID | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get attendance for all branches (or filter by branch_id/class_id)."""
    q = db.query(Student).filter(Student.admission_number.isnot(None))
    if branch_id:
        q = q.filter(Student.branch_id == branch_id)
    if class_id:
        q = q.filter(Student.class_id == class_id)
    students = q.order_by(Student.branch_id, Student.class_id, Student.name).all()
    student_ids = [s.id for s in students]
    att_map = {a.student_id: a for a in db.query(Attendance).filter(
        Attendance.date == att_date,
        Attendance.student_id.in_(student_ids),
    ).all()}
    by_branch: dict[str, dict] = {}
    for s in students:
        branch_name = "—"
        if s.branch_id:
            b = db.query(Branch).filter(Branch.id == s.branch_id).first()
            branch_name = b.name if b else "—"
        cls_name = "—"
        if s.class_id:
            c = db.query(Class).filter(Class.id == s.class_id).first()
            cls_name = c.name if c else "—"
        key = f"{branch_name}|{cls_name}"
        if key not in by_branch:
            by_branch[key] = {"branch": branch_name, "class": cls_name, "students": []}
        a = att_map.get(s.id)
        by_branch[key]["students"].append({
            "id": str(s.id),
            "admission_number": s.admission_number,
            "name": s.name,
            "status": a.status if a else "present",
        })
    return {"date": att_date.isoformat(), "by_branch_class": list(by_branch.values())}


@router.get("/attendance/history")
def get_attendance_history(
    period: str = "week",
    branch_id: UUID | None = None,
    class_id: UUID | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get attendance history. period=week or month. Optional branch_id/class_id filter."""
    q = db.query(Student).filter(Student.admission_number.isnot(None))
    if branch_id:
        q = q.filter(Student.branch_id == branch_id)
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
    by_student: dict[str, dict] = {}
    for s in students:
        branch_name = "—"
        if s.branch_id:
            b = db.query(Branch).filter(Branch.id == s.branch_id).first()
            branch_name = b.name if b else "—"
        cls_name = "—"
        if s.class_id:
            c = db.query(Class).filter(Class.id == s.class_id).first()
            cls_name = c.name if c else "—"
        by_student[str(s.id)] = {
            "name": s.name,
            "admission_number": s.admission_number,
            "branch_name": branch_name,
            "class_name": cls_name,
            "dates": {},
        }
    for a in atts:
        dk = a.date.isoformat()
        if dk not in by_date:
            by_date[dk] = []
        by_date[dk].append({"student_id": str(a.student_id), "status": a.status})
        if str(a.student_id) in by_student:
            by_student[str(a.student_id)]["dates"][dk] = a.status
    dates = sorted(by_date.keys())
    return {"period": period, "start": start_d.isoformat(), "end": end_d.isoformat(), "dates": dates, "by_date": by_date, "by_student": by_student}


@router.get("/students/{student_id}/attendance")
def get_student_attendance(
    student_id: UUID,
    days: int = 30,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get attendance records for a specific student for the last N days."""
    # Get student details
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.admission_number.isnot(None),
    ).first()
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Get attendance records for the last N days
    cutoff_date = date.today() - timedelta(days=days)
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


@router.put("/students/{student_id}/attendance")
def update_student_attendance(
    student_id: UUID,
    att_date: date,
    status: str,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Update attendance status for a specific student on a specific date."""
    # Validate student exists
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.admission_number.isnot(None),
    ).first()
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Validate status
    if status not in ("present", "absent", "leave"):
        raise HTTPException(status_code=400, detail="Invalid status. Must be 'present', 'absent', or 'leave'")
    
    # Find or create attendance record
    attendance = db.query(Attendance).filter(
        Attendance.student_id == student_id,
        Attendance.date == att_date,
    ).first()
    
    if not attendance:
        attendance = Attendance(student_id=student_id, date=att_date, status=status, marked_by=_.id)
        db.add(attendance)
    else:
        attendance.status = status
        attendance.marked_by = _.id
    
    db.commit()
    db.refresh(attendance)
    
    return {
        "id": str(attendance.id),
        "student_id": str(attendance.student_id),
        "date": attendance.date.isoformat(),
        "status": attendance.status,
    }


# --- Fee Management ---
@router.get("/students/{student_id}/fees", response_model=FeesDetailResponse)
def get_student_fees(
    student_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get fee structure and payment history for a specific student."""
    student = db.query(Student).filter(Student.id == student_id).first()
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    fee_struct = db.query(FeeStructure).filter(FeeStructure.student_id == student_id).first()
    
    # Get all payments for this student
    payments = db.query(FeePayment).filter(FeePayment.student_id == student_id).all()
    
    # Calculate paid amounts per component
    paid_amounts = {}
    for payment in payments:
        if payment.component not in paid_amounts:
            paid_amounts[payment.component] = 0.0
        paid_amounts[payment.component] += payment.amount_paid
    
    # If no fee structure, return defaults with zero values
    if not fee_struct:
        return FeesDetailResponse(
            student_id=str(student.id),
            student_name=student.name,
            admission_number=student.admission_number or "",
            advance_fees=0.0,
            term_fee_1=0.0,
            term_fee_2=0.0,
            term_fee_3=0.0,
            total_due=0.0,
            advance_fees_paid=0.0,
            term_fee_1_paid=0.0,
            term_fee_2_paid=0.0,
            term_fee_3_paid=0.0,
            total_paid=0.0,
            advance_fees_balance=0.0,
            term_fee_1_balance=0.0,
            term_fee_2_balance=0.0,
            term_fee_3_balance=0.0,
            total_balance=0.0,
            payments=[],
        )
    
    # Calculate balances
    advance_fees_paid = paid_amounts.get("advance_fees", 0.0)
    term_fee_1_paid = paid_amounts.get("term_fee_1", 0.0)
    term_fee_2_paid = paid_amounts.get("term_fee_2", 0.0)
    term_fee_3_paid = paid_amounts.get("term_fee_3", 0.0)
    total_paid = sum(paid_amounts.values())
    
    advance_fees_balance = fee_struct.advance_fees - advance_fees_paid
    term_fee_1_balance = fee_struct.term_fee_1 - term_fee_1_paid
    term_fee_2_balance = fee_struct.term_fee_2 - term_fee_2_paid
    term_fee_3_balance = fee_struct.term_fee_3 - term_fee_3_paid
    total_balance = (fee_struct.advance_fees + fee_struct.term_fee_1 + fee_struct.term_fee_2 + fee_struct.term_fee_3) - total_paid
    
    return FeesDetailResponse(
        student_id=str(student.id),
        student_name=student.name,
        admission_number=student.admission_number or "",
        advance_fees=fee_struct.advance_fees,
        term_fee_1=fee_struct.term_fee_1,
        term_fee_2=fee_struct.term_fee_2,
        term_fee_3=fee_struct.term_fee_3,
        total_due=fee_struct.advance_fees + fee_struct.term_fee_1 + fee_struct.term_fee_2 + fee_struct.term_fee_3,
        advance_fees_paid=advance_fees_paid,
        term_fee_1_paid=term_fee_1_paid,
        term_fee_2_paid=term_fee_2_paid,
        term_fee_3_paid=term_fee_3_paid,
        total_paid=total_paid,
        advance_fees_balance=advance_fees_balance,
        term_fee_1_balance=term_fee_1_balance,
        term_fee_2_balance=term_fee_2_balance,
        term_fee_3_balance=term_fee_3_balance,
        total_balance=total_balance,
        payments=[
            FeePaymentResponse(
                id=str(p.id),
                component=p.component,
                amount_paid=p.amount_paid,
                payment_mode=p.payment_mode,
                payment_date=p.payment_date,
                created_at=p.created_at,
            )
            for p in payments
        ],
    )


@router.post("/students/{student_id}/fees", response_model=FeeStructureResponse)
def save_student_fees(
    student_id: UUID,
    data: FeeStructureCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Create or update fee structure for a student."""
    student = db.query(Student).filter(Student.id == student_id).first()
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    fee_struct = db.query(FeeStructure).filter(FeeStructure.student_id == student_id).first()
    
    if fee_struct:
        # Update existing fee structure
        fee_struct.advance_fees = data.advance_fees
        fee_struct.term_fee_1 = data.term_fee_1
        fee_struct.term_fee_2 = data.term_fee_2
        fee_struct.term_fee_3 = data.term_fee_3
    else:
        # Create new fee structure
        fee_struct = FeeStructure(
            student_id=student_id,
            branch_id=student.branch_id,
            advance_fees=data.advance_fees,
            term_fee_1=data.term_fee_1,
            term_fee_2=data.term_fee_2,
            term_fee_3=data.term_fee_3,
        )
        db.add(fee_struct)
    
    db.commit()
    db.refresh(fee_struct)
    
    return FeeStructureResponse(
        id=str(fee_struct.id),
        student_id=str(fee_struct.student_id),
        branch_id=str(fee_struct.branch_id),
        advance_fees=fee_struct.advance_fees,
        term_fee_1=fee_struct.term_fee_1,
        term_fee_2=fee_struct.term_fee_2,
        term_fee_3=fee_struct.term_fee_3,
        created_at=fee_struct.created_at,
        updated_at=fee_struct.updated_at,
    )


@router.post("/students/{student_id}/fees/payment")
def record_fee_payment(
    student_id: UUID,
    data: FeePaymentCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Record a fee payment for a student."""
    student = db.query(Student).filter(Student.id == student_id).first()
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    fee_struct = db.query(FeeStructure).filter(FeeStructure.student_id == student_id).first()
    
    if not fee_struct:
        raise HTTPException(status_code=404, detail="Fee structure not found for this student")
    
    # Validate component
    valid_components = ["advance_fees", "term_fee_1", "term_fee_2", "term_fee_3"]
    if data.component not in valid_components:
        raise HTTPException(status_code=400, detail=f"Invalid component. Must be one of: {', '.join(valid_components)}")
    
    # Validate payment_mode
    valid_modes = ["cash", "upi", "net_banking", "cheque", "bank_transfer"]
    if data.payment_mode not in valid_modes:
        raise HTTPException(status_code=400, detail=f"Invalid payment_mode. Must be one of: {', '.join(valid_modes)}")
    
    # Create payment record
    payment = FeePayment(
        fee_structure_id=fee_struct.id,
        student_id=student_id,
        component=data.component,
        amount_paid=data.amount_paid,
        payment_mode=data.payment_mode,
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)
    
    return FeePaymentResponse(
        id=str(payment.id),
        component=payment.component,
        amount_paid=payment.amount_paid,
        payment_mode=payment.payment_mode,
        payment_date=payment.payment_date,
        created_at=payment.created_at,
    )


@router.get("/students/{student_id}/fees/payments", response_model=list[FeePaymentResponse])
def get_student_fee_payments(
    student_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get all fee payment records for a student."""
    student = db.query(Student).filter(Student.id == student_id).first()
    
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    payments = db.query(FeePayment).filter(FeePayment.student_id == student_id).order_by(FeePayment.created_at.desc()).all()
    
    return [
        FeePaymentResponse(
            id=str(p.id),
            component=p.component,
            amount_paid=p.amount_paid,
            payment_mode=p.payment_mode,
            payment_date=p.payment_date,
            created_at=p.created_at,
        )
        for p in payments
    ]


# --- Marks Cards ---
class MarksCardUpsert(BaseModel):
    academic_year: str = "2024-25"
    data: dict[str, Any] = {}


@router.get("/marks/{student_id}")
def get_marks(
    student_id: UUID,
    academic_year: str = Query("2024-25"),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get marks for a student."""
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    card = db.query(MarksCard).filter(
        MarksCard.student_id == student_id,
        MarksCard.academic_year == academic_year
    ).first()
    
    if not card:
        return {
            "student_id": str(student_id),
            "academic_year": academic_year,
            "data": {},
            "sent_to_parent_at": None
        }
    
    return {
        "id": str(card.id),
        "student_id": str(card.student_id),
        "academic_year": card.academic_year,
        "data": card.data or {},
        "sent_to_parent_at": card.sent_to_parent_at.isoformat() if card.sent_to_parent_at else None,
    }


@router.put("/marks/{student_id}")
def upsert_marks(
    student_id: UUID,
    body: MarksCardUpsert,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Update marks for a student."""
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    card = db.query(MarksCard).filter(
        MarksCard.student_id == student_id,
        MarksCard.academic_year == body.academic_year
    ).first()
    
    if card:
        card.data = body.data
    else:
        card = MarksCard(
            student_id=student_id,
            academic_year=body.academic_year,
            data=body.data
        )
        db.add(card)
    
    db.commit()
    db.refresh(card)
    
    return {
        "id": str(card.id),
        "student_id": str(card.student_id),
        "academic_year": card.academic_year,
        "data": card.data or {},
    }


@router.post("/marks/{student_id}/send-to-parent")
def send_marks_to_parent(
    student_id: UUID,
    academic_year: str = Query("2024-25"),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Mark marks card as sent to parent."""
    card = db.query(MarksCard).filter(
        MarksCard.student_id == student_id,
        MarksCard.academic_year == academic_year
    ).first()
    
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


# --- Analytics & Reports ---

@router.get("/analytics")
def get_analytics(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get comprehensive analytics data for admin reports."""
    from datetime import datetime, timedelta
    from sqlalchemy import extract, and_
    
    # Students by grade/class
    students_by_grade = []
    classes = db.query(Class).all()
    for cls in classes:
        count = db.query(func.count(Student.id)).filter(
            Student.class_id == cls.id,
            Student.admission_number.isnot(None)
        ).scalar() or 0
        if count > 0:
            students_by_grade.append({
                "grade": cls.name,
                "count": count,
                "branch": db.query(Branch.name).filter(Branch.id == cls.branch_id).scalar() or "Unknown"
            })
    
    # Enquiries and admissions by month (last 6 months)
    today = datetime.now()
    
    enquiries_by_month = []
    admissions_by_month = []
    
    for i in range(6):
        month_start = today - timedelta(days=30 * (5 - i))
        month_end = month_start + timedelta(days=30)
        month_name = month_start.strftime("%b %Y")
        
        # Count enquiries created in this month
        enq_count = db.query(func.count(Enquiry.id)).filter(
            and_(
                Enquiry.created_at >= month_start,
                Enquiry.created_at < month_end
            )
        ).scalar() or 0
        
        # Count admissions (students admitted) in this month
        adm_count = db.query(func.count(Student.id)).filter(
            and_(
                Student.created_at >= month_start,
                Student.created_at < month_end,
                Student.admission_number.isnot(None)
            )
        ).scalar() or 0
        
        enquiries_by_month.append({"month": month_name, "count": enq_count})
        admissions_by_month.append({"month": month_name, "count": adm_count})
    
    # Revenue collected
    total_fees_paid = db.query(func.sum(FeePayment.amount_paid)).scalar() or 0.0
    total_fees_due = 0.0
    
    # Calculate total due from fee structures
    fee_structures = db.query(FeeStructure).all()
    for fs in fee_structures:
        if fs.advance_fees:
            total_fees_due += float(fs.advance_fees)
        if fs.term_fee_1:
            total_fees_due += float(fs.term_fee_1)
        if fs.term_fee_2:
            total_fees_due += float(fs.term_fee_2)
        if fs.term_fee_3:
            total_fees_due += float(fs.term_fee_3)
    
    outstanding = total_fees_due - total_fees_paid
    
    # Enquiry conversion stats
    total_enquiries = db.query(func.count(Enquiry.id)).scalar() or 0
    converted_enquiries = db.query(func.count(Enquiry.id)).filter(
        Enquiry.status == "converted"
    ).scalar() or 0
    pending_enquiries = db.query(func.count(Enquiry.id)).filter(
        Enquiry.status == "pending"
    ).scalar() or 0
    rejected_enquiries = db.query(func.count(Enquiry.id)).filter(
        Enquiry.status == "rejected"
    ).scalar() or 0
    
    return {
        "students_by_grade": students_by_grade,
        "enquiries_by_month": enquiries_by_month,
        "admissions_by_month": admissions_by_month,
        "revenue": {
            "total_collected": float(total_fees_paid),
            "total_due": float(total_fees_due),
            "outstanding": float(outstanding),
            "collection_rate": round((total_fees_paid / total_fees_due * 100), 2) if total_fees_due > 0 else 0.0
        },
        "enquiry_stats": {
            "total": total_enquiries,
            "converted": converted_enquiries,
            "pending": pending_enquiries,
            "rejected": rejected_enquiries,
            "conversion_rate": round((converted_enquiries / total_enquiries * 100), 2) if total_enquiries > 0 else 0.0
        }
    }
