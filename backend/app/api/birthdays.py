"""Birthday wishes API — today and upcoming birthdays scoped per user role."""
from datetime import date, timedelta
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import extract, or_
from sqlalchemy.orm import Session

from app.core.auth import get_current_user
from app.core.database import get_db
from app.models.branch import Branch, BranchAssignment, Class
from app.models.student import ParentStudentLink, Student
from app.models.user import User

router = APIRouter(prefix="/birthdays", tags=["birthdays"])


def _years_old(dob: date, today: date) -> int:
    return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))


def _next_occurrence(dob: date, today: date) -> date:
    try:
        nxt = dob.replace(year=today.year)
    except ValueError:
        nxt = date(today.year, 2, 28)
    if nxt < today:
        try:
            nxt = dob.replace(year=today.year + 1)
        except ValueError:
            nxt = date(today.year + 1, 2, 28)
    return nxt


def _scope_student_ids(db: Session, user: User) -> Optional[List[UUID]]:
    """Return list of student IDs the user may see. None means "all"."""
    if user.role in ("admin", "toddlers", "daycare"):
        return None
    if user.role == "coordinator":
        a = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).all()
        branch_ids = list({x.branch_id for x in a})
        if not branch_ids:
            return []
        rows = db.query(Student.id).filter(Student.branch_id.in_(branch_ids)).all()
        return [r[0] for r in rows]
    if user.role == "teacher":
        a = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == user.id,
            BranchAssignment.class_id.isnot(None),
        ).all()
        class_ids = list({x.class_id for x in a})
        if not class_ids:
            return []
        rows = db.query(Student.id).filter(Student.class_id.in_(class_ids)).all()
        return [r[0] for r in rows]
    if user.role == "parent":
        rows = db.query(ParentStudentLink.student_id).filter(
            ParentStudentLink.user_id == user.id
        ).all()
        return [r[0] for r in rows]
    return []


def _scope_staff_query(db: Session, user: User):
    """Return staff users (excluding the caller) the user may see for birthday list."""
    if user.role == "parent":
        return None
    q = db.query(User).filter(
        User.date_of_birth.isnot(None),
        User.id != user.id,
        User.role.in_(["admin", "coordinator", "teacher", "toddlers", "daycare", "bus_staff"]),
    )
    if user.role == "coordinator":
        a = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).all()
        branch_ids = list({x.branch_id for x in a})
        if not branch_ids:
            return q.filter(False)
        peer_ids = db.query(BranchAssignment.user_id).filter(
            BranchAssignment.branch_id.in_(branch_ids)
        ).subquery()
        admin_ids = db.query(User.id).filter(User.role == "admin").subquery()
        q = q.filter(or_(User.id.in_(peer_ids), User.id.in_(admin_ids)))
    elif user.role == "teacher":
        a = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).all()
        branch_ids = list({x.branch_id for x in a})
        if not branch_ids:
            return q.filter(False)
        peer_ids = db.query(BranchAssignment.user_id).filter(
            BranchAssignment.branch_id.in_(branch_ids)
        ).subquery()
        admin_ids = db.query(User.id).filter(User.role == "admin").subquery()
        q = q.filter(or_(User.id.in_(peer_ids), User.id.in_(admin_ids)))
    return q


def _student_payload(db: Session, s: Student, today: date) -> dict:
    cls = db.query(Class).filter(Class.id == s.class_id).first() if s.class_id else None
    branch = db.query(Branch).filter(Branch.id == s.branch_id).first() if s.branch_id else None
    age = _years_old(s.date_of_birth, today)
    next_dob = _next_occurrence(s.date_of_birth, today)
    return {
        "id": str(s.id),
        "name": s.name,
        "kind": "student",
        "date_of_birth": s.date_of_birth.isoformat(),
        "turning_age": age + (0 if next_dob == today else 1),
        "next_birthday": next_dob.isoformat(),
        "days_until": (next_dob - today).days,
        "class_name": cls.name if cls else None,
        "branch_name": branch.name if branch else None,
    }


def _user_payload(u: User, today: date) -> dict:
    next_dob = _next_occurrence(u.date_of_birth, today)
    return {
        "id": str(u.id),
        "name": u.full_name,
        "kind": "staff",
        "role": u.role,
        "date_of_birth": u.date_of_birth.isoformat() if u.date_of_birth else None,
        "turning_age": _years_old(u.date_of_birth, today) + (0 if next_dob == today else 1),
        "next_birthday": next_dob.isoformat(),
        "days_until": (next_dob - today).days,
    }


@router.get("/today")
def birthdays_today(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    is_my_birthday = bool(
        user.date_of_birth
        and user.date_of_birth.month == today.month
        and user.date_of_birth.day == today.day
    )

    student_ids = _scope_student_ids(db, user)
    sq = db.query(Student).filter(
        extract("month", Student.date_of_birth) == today.month,
        extract("day", Student.date_of_birth) == today.day,
    )
    if student_ids is None:
        students = sq.all()
    elif not student_ids:
        students = []
    else:
        students = sq.filter(Student.id.in_(student_ids)).all()

    staff_q = _scope_staff_query(db, user)
    if staff_q is None:
        staff = []
    else:
        staff = staff_q.filter(
            extract("month", User.date_of_birth) == today.month,
            extract("day", User.date_of_birth) == today.day,
        ).all()

    return {
        "today": today.isoformat(),
        "is_my_birthday": is_my_birthday,
        "my_name": user.full_name,
        "my_age": _years_old(user.date_of_birth, today) if user.date_of_birth else None,
        "students": [_student_payload(db, s, today) for s in students],
        "staff": [_user_payload(u, today) for u in staff],
    }


@router.get("/upcoming")
def birthdays_upcoming(
    days: int = Query(7, ge=1, le=60),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    today = date.today()
    horizon = today + timedelta(days=days)

    student_ids = _scope_student_ids(db, user)
    students: List[Student] = []
    if student_ids is None:
        students = db.query(Student).all()
    elif student_ids:
        students = db.query(Student).filter(Student.id.in_(student_ids)).all()

    students_within: List[dict] = []
    for s in students:
        nxt = _next_occurrence(s.date_of_birth, today)
        if today <= nxt <= horizon:
            students_within.append(_student_payload(db, s, today))
    students_within.sort(key=lambda x: x["days_until"])

    staff_q = _scope_staff_query(db, user)
    staff_within: List[dict] = []
    if staff_q is not None:
        for u in staff_q.all():
            if not u.date_of_birth:
                continue
            nxt = _next_occurrence(u.date_of_birth, today)
            if today <= nxt <= horizon:
                staff_within.append(_user_payload(u, today))
        staff_within.sort(key=lambda x: x["days_until"])

    return {
        "today": today.isoformat(),
        "days": days,
        "students": students_within,
        "staff": staff_within,
    }
