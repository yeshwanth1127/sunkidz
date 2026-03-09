from uuid import UUID
from datetime import date, timedelta, datetime
import logging
from fastapi import APIRouter, Depends, HTTPException, status, Query, Body
from sqlalchemy.orm import Session
from sqlalchemy import func
from collections import defaultdict

from app.core.database import get_db
from app.core.auth import get_current_user, require_admin
from app.core.config import settings
from app.core.security import get_password_hash
from app.models.user import User
from app.models.branch import Branch, Class, BranchAssignment
from app.models.student import Student
from app.models.attendance import Attendance
from app.models.staff_attendance import StaffAttendance
from app.models.enquiry import Enquiry
from app.models.fees import FeeStructure, FeePayment
from app.services.notification_service import send_fee_notification
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

router = APIRouter(prefix="/admin", tags=["admin"])
logger = logging.getLogger(__name__)


def _ensure_branch_classes(db: Session, branch_id: UUID) -> None:
    """Create default classes for a branch if missing."""
    for name in settings.default_branch_classes:
        if not db.query(Class).filter(Class.branch_id == branch_id, Class.name == name).first():
            db.add(Class(branch_id=branch_id, name=name, academic_year="2024-25"))
    db.commit()


def _generate_admission_number_for_branch(
    db: Session,
    branch: Branch,
    admission_date: date,
    exclude_student_id: UUID | None = None,
) -> str:
    """Generate admission number format: skz(branch_code)(year)(date)[nn]."""
    code = (branch.code or "main").lower()[:10]
    year = admission_date.strftime("%Y")
    day = admission_date.strftime("%m%d")
    base = f"skz{code}{year}{day}"

    q = db.query(Student).filter(Student.admission_number.like(f"{base}%"))
    if exclude_student_id is not None:
        q = q.filter(Student.id != exclude_student_id)
    existing = q.count()

    if existing > 0:
        return f"{base}{existing + 1:02d}"
    return base


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


@router.put("/students/{student_id}/branch")
def shift_student_branch(
    student_id: UUID,
    data: dict = Body(...),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Shift student to another branch and optionally assign class."""
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.admission_number.isnot(None),
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    branch_id_raw = data.get("branch_id")
    class_id_raw = data.get("class_id")
    if not branch_id_raw:
        raise HTTPException(status_code=400, detail="branch_id is required")

    try:
        branch_id = UUID(str(branch_id_raw))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid branch_id")

    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")

    cls = None
    if class_id_raw:
        try:
            class_id = UUID(str(class_id_raw))
        except Exception:
            raise HTTPException(status_code=400, detail="Invalid class_id")
        cls = db.query(Class).filter(Class.id == class_id, Class.branch_id == branch_id).first()
        if not cls:
            raise HTTPException(status_code=400, detail="Class not found in target branch")
    else:
        # Keep assignment valid by defaulting to first class of the selected branch when available.
        cls = db.query(Class).filter(Class.branch_id == branch_id).order_by(Class.name.asc()).first()

    old_branch_id = student.branch_id

    student.branch_id = branch.id
    student.class_id = cls.id if cls else None

    if old_branch_id != branch.id:
        admission_dt = student.created_at.date() if student.created_at else date.today()
        student.admission_number = _generate_admission_number_for_branch(
            db,
            branch,
            admission_dt,
            exclude_student_id=student.id,
        )

    db.commit()
    db.refresh(student)

    return {
        "ok": True,
        "student_id": str(student.id),
        "branch_id": str(branch.id),
        "branch_name": branch.name,
        "class_id": str(cls.id) if cls else None,
        "class_name": cls.name if cls else None,
        "admission_number": student.admission_number,
    }


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


# --- Staff Attendance (View) ---

@router.get("/staff-attendance")
def get_staff_attendance(
    att_date: date,
    branch_id: UUID | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get staff attendance for all branches (or filter by branch_id) on a given date."""
    branches = db.query(Branch).all()
    if branch_id:
        branches = [b for b in branches if b.id == branch_id]
    
    by_branch: dict[str, dict] = {}
    
    for branch in branches:
        # Get all teachers assigned to this branch
        assignments = (
            db.query(BranchAssignment)
            .join(BranchAssignment.user)
            .filter(
                BranchAssignment.branch_id == branch.id,
                User.role == "teacher",
            )
            .all()
        )
        
        user_ids = [a.user_id for a in assignments]
        att_map = {a.user_id: a for a in db.query(StaffAttendance).filter(
            StaffAttendance.date == att_date,
            StaffAttendance.user_id.in_(user_ids),
        ).all()} if user_ids else {}
        
        staff_list = []
        for a in assignments:
            att = att_map.get(a.user_id)
            cls_name = None
            if a.class_id:
                c = db.query(Class).filter(Class.id == a.class_id).first()
                cls_name = c.name if c else None
            staff_list.append({
                "user_id": str(a.user_id),
                "full_name": a.user.full_name,
                "email": a.user.email,
                "class_name": cls_name,
                "status": att.status if att else "present",
            })
        
        if staff_list:  # Only include branches with staff
            by_branch[branch.name] = {
                "branch_id": str(branch.id),
                "branch_name": branch.name,
                "staff": staff_list,
                "summary": {
                    "total": len(staff_list),
                    "present": sum(1 for s in staff_list if s["status"] == "present"),
                    "absent": sum(1 for s in staff_list if s["status"] == "absent"),
                    "leave": sum(1 for s in staff_list if s["status"] == "leave"),
                }
            }
    
    return {
        "date": att_date.isoformat(),
        "by_branch": list(by_branch.values()),
    }


@router.get("/staff-attendance/history")
def get_staff_attendance_history(
    period: str = "week",
    branch_id: UUID | None = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get staff attendance history. period=week or month. Optional branch_id filter."""
    branches = db.query(Branch).all()
    if branch_id:
        branches = [b for b in branches if b.id == branch_id]
    
    all_assignments = []
    for branch in branches:
        assignments = (
            db.query(BranchAssignment)
            .join(BranchAssignment.user)
            .filter(
                BranchAssignment.branch_id == branch.id,
                User.role == "teacher",
            )
            .all()
        )
        all_assignments.extend(assignments)
    
    user_ids = [a.user_id for a in all_assignments]
    if not user_ids:
        return {"period": period, "start": date.today().isoformat(), "end": date.today().isoformat(), "dates": [], "by_branch": []}
    
    end_d = date.today()
    start_d = end_d - timedelta(days=7 if period == "week" else 30)
    atts = db.query(StaffAttendance).filter(
        StaffAttendance.user_id.in_(user_ids),
        StaffAttendance.date >= start_d,
        StaffAttendance.date <= end_d,
    ).all()
    
    by_date: dict[str, list] = {}
    by_branch: dict[str, dict] = {}
    
    for a in all_assignments:
        branch_name = "—"
        if a.branch_id:
            b = db.query(Branch).filter(Branch.id == a.branch_id).first()
            branch_name = b.name if b else "—"
        
        if branch_name not in by_branch:
            by_branch[branch_name] = {
                "branch_id": str(a.branch_id) if a.branch_id else None,
                "branch_name": branch_name,
                "staff": {}
            }
        
        cls_name = None
        if a.class_id:
            c = db.query(Class).filter(Class.id == a.class_id).first()
            cls_name = c.name if c else None
        
        by_branch[branch_name]["staff"][str(a.user_id)] = {
            "full_name": a.user.full_name,
            "class_name": cls_name,
            "dates": {}
        }
    
    for att in atts:
        dk = att.date.isoformat()
        if dk not in by_date:
            by_date[dk] = []
        by_date[dk].append({"user_id": str(att.user_id), "status": att.status})
        
        # Find the branch for this user and add to dates
        assignment = next((a for a in all_assignments if a.user_id == att.user_id), None)
        if assignment:
            branch_name = "—"
            if assignment.branch_id:
                b = db.query(Branch).filter(Branch.id == assignment.branch_id).first()
                branch_name = b.name if b else "—"
            
            if branch_name in by_branch and str(att.user_id) in by_branch[branch_name]["staff"]:
                by_branch[branch_name]["staff"][str(att.user_id)]["dates"][dk] = att.status
    
    dates = sorted(by_date.keys())
    return {
        "period": period,
        "start": start_d.isoformat(),
        "end": end_d.isoformat(),
        "dates": dates,
        "by_date": by_date,
        "by_branch": list(by_branch.values()),
    }


def _build_fees_detail(student: Student, fee_structure: FeeStructure | None, payments: list[FeePayment]):
    advance_fees = float(fee_structure.advance_fees) if fee_structure else 0.0
    term_fee_1 = float(fee_structure.term_fee_1) if fee_structure else 0.0
    term_fee_2 = float(fee_structure.term_fee_2) if fee_structure else 0.0
    term_fee_3 = float(fee_structure.term_fee_3) if fee_structure else 0.0

    paid = {
        "advance_fees": 0.0,
        "term_fee_1": 0.0,
        "term_fee_2": 0.0,
        "term_fee_3": 0.0,
    }
    for p in payments:
        if p.component in paid:
            paid[p.component] += float(p.amount_paid or 0.0)

    total_due = advance_fees + term_fee_1 + term_fee_2 + term_fee_3
    total_paid = sum(paid.values())

    return {
        "student_id": str(student.id),
        "student_name": student.name,
        "admission_number": student.admission_number,
        "advance_fees": advance_fees,
        "term_fee_1": term_fee_1,
        "term_fee_2": term_fee_2,
        "term_fee_3": term_fee_3,
        "total_due": total_due,
        "advance_fees_paid": paid["advance_fees"],
        "term_fee_1_paid": paid["term_fee_1"],
        "term_fee_2_paid": paid["term_fee_2"],
        "term_fee_3_paid": paid["term_fee_3"],
        "total_paid": total_paid,
        "advance_fees_balance": max(advance_fees - paid["advance_fees"], 0.0),
        "term_fee_1_balance": max(term_fee_1 - paid["term_fee_1"], 0.0),
        "term_fee_2_balance": max(term_fee_2 - paid["term_fee_2"], 0.0),
        "term_fee_3_balance": max(term_fee_3 - paid["term_fee_3"], 0.0),
        "total_balance": max(total_due - total_paid, 0.0),
        "payments": [
            {
                "id": str(p.id),
                "component": p.component,
                "amount_paid": float(p.amount_paid or 0.0),
                "payment_mode": p.payment_mode,
                "payment_date": p.payment_date.isoformat() if p.payment_date else None,
                "created_at": p.created_at.isoformat() if p.created_at else None,
            }
            for p in payments
        ],
    }


@router.get("/students/{student_id}/fees")
def get_student_fees(
    student_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.admission_number.isnot(None),
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    fee_structure = db.query(FeeStructure).filter(FeeStructure.student_id == student_id).first()
    payments = db.query(FeePayment).filter(FeePayment.student_id == student_id).order_by(FeePayment.payment_date.desc()).all()
    return _build_fees_detail(student, fee_structure, payments)


@router.put("/students/{student_id}/fees")
def upsert_student_fees(
    student_id: UUID,
    body: dict,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.admission_number.isnot(None),
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if not student.branch_id:
        raise HTTPException(status_code=400, detail="Student branch not set")

    fee_structure = db.query(FeeStructure).filter(FeeStructure.student_id == student_id).first()
    if not fee_structure:
        fee_structure = FeeStructure(student_id=student_id, branch_id=student.branch_id)
        db.add(fee_structure)

    fee_structure.advance_fees = float(body.get("advance_fees", fee_structure.advance_fees or 0.0))
    fee_structure.term_fee_1 = float(body.get("term_fee_1", fee_structure.term_fee_1 or 0.0))
    fee_structure.term_fee_2 = float(body.get("term_fee_2", fee_structure.term_fee_2 or 0.0))
    fee_structure.term_fee_3 = float(body.get("term_fee_3", fee_structure.term_fee_3 or 0.0))

    db.commit()
    db.refresh(fee_structure)
    
    # Send WhatsApp notification to parents (non-blocking)
    try:
        send_fee_notification(student_id, db)
    except Exception as ex:
        logger.error(f"Failed to send fee notification for student {student_id}: {str(ex)}")
    
    payments = db.query(FeePayment).filter(FeePayment.student_id == student_id).order_by(FeePayment.payment_date.desc()).all()
    return _build_fees_detail(student, fee_structure, payments)


@router.post("/students/{student_id}/fees/payments")
def record_student_fee_payment(
    student_id: UUID,
    body: dict,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.admission_number.isnot(None),
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    if not student.branch_id:
        raise HTTPException(status_code=400, detail="Student branch not set")

    component = str(body.get("component", "")).strip()
    amount_paid = body.get("amount_paid")
    payment_mode = str(body.get("payment_mode", "")).strip()

    allowed_components = {"advance_fees", "term_fee_1", "term_fee_2", "term_fee_3"}
    if component not in allowed_components:
        raise HTTPException(status_code=400, detail="Invalid fee component")
    try:
        amount_paid = float(amount_paid)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid amount_paid")
    if amount_paid <= 0:
        raise HTTPException(status_code=400, detail="amount_paid must be > 0")
    if not payment_mode:
        raise HTTPException(status_code=400, detail="payment_mode is required")

    fee_structure = db.query(FeeStructure).filter(FeeStructure.student_id == student_id).first()
    if not fee_structure:
        fee_structure = FeeStructure(student_id=student_id, branch_id=student.branch_id)
        db.add(fee_structure)
        db.flush()

    payment = FeePayment(
        fee_structure_id=fee_structure.id,
        student_id=student_id,
        component=component,
        amount_paid=amount_paid,
        payment_mode=payment_mode,
        marked_by=_.id,
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)

    return {
        "id": str(payment.id),
        "component": payment.component,
        "amount_paid": float(payment.amount_paid or 0.0),
        "payment_mode": payment.payment_mode,
        "payment_date": payment.payment_date.isoformat() if payment.payment_date else None,
        "created_at": payment.created_at.isoformat() if payment.created_at else None,
    }


@router.get("/students/{student_id}/fees/payments")
def get_student_fee_payments(
    student_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    student = db.query(Student).filter(
        Student.id == student_id,
        Student.admission_number.isnot(None),
    ).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    payments = db.query(FeePayment).filter(FeePayment.student_id == student_id).order_by(FeePayment.payment_date.desc()).all()
    return {
        "payments": [
            {
                "id": str(p.id),
                "component": p.component,
                "amount_paid": float(p.amount_paid or 0.0),
                "payment_mode": p.payment_mode,
                "payment_date": p.payment_date.isoformat() if p.payment_date else None,
                "created_at": p.created_at.isoformat() if p.created_at else None,
            }
            for p in payments
        ]
    }


@router.get("/analytics")
def get_analytics(
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Return analytics payload used by admin reports and dashboard fee metrics."""
    now = datetime.utcnow()

    # Revenue (fees)
    fee_structures = db.query(FeeStructure).all()
    total_due = sum(
        (fs.advance_fees or 0.0)
        + (fs.term_fee_1 or 0.0)
        + (fs.term_fee_2 or 0.0)
        + (fs.term_fee_3 or 0.0)
        for fs in fee_structures
    )
    total_collected = db.query(func.coalesce(func.sum(FeePayment.amount_paid), 0.0)).scalar() or 0.0
    outstanding = max(total_due - total_collected, 0.0)
    collection_rate = (total_collected / total_due * 100.0) if total_due > 0 else 0.0

    # Students by grade (branch-aware for disambiguating repeated grade names)
    # Include all branches so empty branches are still visible in analytics.
    students_by_grade = []
    branches = db.query(Branch).order_by(Branch.name.asc()).all()
    for branch in branches:
        branch_classes = sorted(branch.classes or [], key=lambda c: (c.name or ""))
        if not branch_classes:
            students_by_grade.append(
                {
                    "branch": branch.name,
                    "grade": "(no classes)",
                    "count": 0,
                }
            )
            continue

        for cls in branch_classes:
            count = (
                db.query(func.count(Student.id))
                .filter(Student.class_id == cls.id, Student.admission_number.isnot(None))
                .scalar()
                or 0
            )
            students_by_grade.append(
                {
                    "branch": branch.name,
                    "grade": cls.name,
                    "count": int(count),
                }
            )

    # Last 6 months trend buckets
    month_keys: list[tuple[int, int, str]] = []
    for i in range(5, -1, -1):
        y = now.year
        m = now.month - i
        while m <= 0:
            y -= 1
            m += 12
        label = datetime(y, m, 1).strftime("%b %Y")
        month_keys.append((y, m, label))

    enquiries = db.query(Enquiry).all()
    admissions = db.query(Student).filter(Student.admission_number.isnot(None)).all()

    enq_counts: dict[tuple[int, int], int] = defaultdict(int)
    for e in enquiries:
        if e.created_at is None:
            continue
        enq_counts[(e.created_at.year, e.created_at.month)] += 1

    adm_counts: dict[tuple[int, int], int] = defaultdict(int)
    for s in admissions:
        if s.created_at is None:
            continue
        adm_counts[(s.created_at.year, s.created_at.month)] += 1

    enquiries_by_month = [
        {"month": label, "count": int(enq_counts.get((y, m), 0))}
        for y, m, label in month_keys
    ]
    admissions_by_month = [
        {"month": label, "count": int(adm_counts.get((y, m), 0))}
        for y, m, label in month_keys
    ]

    total_enquiries = len(enquiries)
    converted = sum(1 for e in enquiries if (e.status or "").lower() == "converted")
    rejected = sum(1 for e in enquiries if (e.status or "").lower() == "rejected")
    pending = sum(1 for e in enquiries if (e.status or "").lower() in {"pending", "new"})
    conversion_rate = (converted / total_enquiries * 100.0) if total_enquiries > 0 else 0.0

    return {
        "revenue": {
            "total_collected": float(total_collected),
            "total_due": float(total_due),
            "outstanding": float(outstanding),
            "collection_rate": round(collection_rate, 1),
        },
        "students_by_grade": students_by_grade,
        "enquiries_by_month": enquiries_by_month,
        "admissions_by_month": admissions_by_month,
        "enquiry_stats": {
            "total": total_enquiries,
            "converted": converted,
            "pending": pending,
            "rejected": rejected,
            "conversion_rate": round(conversion_rate, 1),
        },
    }
