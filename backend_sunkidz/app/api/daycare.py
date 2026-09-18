import os
import uuid
from datetime import datetime, date
from typing import Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Query
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.core.database import get_db
from app.core.auth import get_current_user, get_optional_user, require_admin
from app.core.security import decode_access_token
from app.models import User, Student, ParentStudentLink, Branch
from app.models.daycare import DaycareGroup, DaycareGroupStudent, DaycareDailyUpdate
from app.schemas.daycare import (
    DaycareGroupCreate,
    DaycareGroupUpdate,
    DaycareGroupResponse,
    DaycareGroupStudentCreate,
    DaycareDailyUpdateCreate,
    DaycareDailyUpdateResponse,
)

router = APIRouter(prefix="/daycare", tags=["daycare"])

UPLOAD_DIR = "uploads"
DAYCARE_UPDATE_DIR = os.path.join(UPLOAD_DIR, "daycare_updates")
os.makedirs(DAYCARE_UPDATE_DIR, exist_ok=True)


def _daycare_staff_student_ids(db: Session, user: User) -> list[UUID]:
    """Get student IDs the daycare staff can post updates for."""
    groups = db.query(DaycareGroup).filter(DaycareGroup.daycare_staff_id == user.id).all()
    student_ids = []
    for g in groups:
        for gs in g.students:
            student_ids.append(gs.student_id)
    return list(set(student_ids))


# ==================== ADMIN: Daycare Groups ====================


@router.post("/admin/groups", response_model=DaycareGroupResponse)
def create_daycare_group(
    data: DaycareGroupCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Admin creates a daycare group and assigns daycare staff."""
    group = DaycareGroup(
        name=data.name,
        branch_id=UUID(data.branch_id),
        daycare_staff_id=UUID(data.daycare_staff_id),
    )
    db.add(group)
    db.commit()
    db.refresh(group)
    branch = db.query(Branch).filter(Branch.id == group.branch_id).first()
    staff = db.query(User).filter(User.id == group.daycare_staff_id).first()
    return DaycareGroupResponse(
        id=str(group.id),
        name=group.name,
        branch_id=str(group.branch_id),
        branch_name=branch.name if branch else None,
        daycare_staff_id=str(group.daycare_staff_id),
        daycare_staff_name=staff.full_name if staff else None,
        student_count=0,
        students=[],
    )


@router.get("/admin/groups", response_model=list[DaycareGroupResponse])
def list_daycare_groups(
    branch_id: Optional[str] = None,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """List all daycare groups."""
    q = db.query(DaycareGroup)
    if branch_id:
        q = q.filter(DaycareGroup.branch_id == UUID(branch_id))
    groups = q.all()
    result = []
    for g in groups:
        branch = db.query(Branch).filter(Branch.id == g.branch_id).first()
        staff = db.query(User).filter(User.id == g.daycare_staff_id).first()
        students = []
        for gs in g.students:
            s = gs.student
            students.append({"id": str(gs.id), "student_id": str(s.id), "student_name": s.name})
        result.append(DaycareGroupResponse(
            id=str(g.id),
            name=g.name,
            branch_id=str(g.branch_id),
            branch_name=branch.name if branch else None,
            daycare_staff_id=str(g.daycare_staff_id),
            daycare_staff_name=staff.full_name if staff else None,
            student_count=len(students),
            students=students,
        ))
    return result


@router.get("/admin/groups/{group_id}", response_model=DaycareGroupResponse)
def get_daycare_group(
    group_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    group = db.query(DaycareGroup).filter(DaycareGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Daycare group not found")
    branch = db.query(Branch).filter(Branch.id == group.branch_id).first()
    staff = db.query(User).filter(User.id == group.daycare_staff_id).first()
    students = []
    for gs in group.students:
        s = gs.student
        students.append({"id": str(gs.id), "student_id": str(s.id), "student_name": s.name})
    return DaycareGroupResponse(
        id=str(group.id),
        name=group.name,
        branch_id=str(group.branch_id),
        branch_name=branch.name if branch else None,
        daycare_staff_id=str(group.daycare_staff_id),
        daycare_staff_name=staff.full_name if staff else None,
        student_count=len(students),
        students=students,
    )


@router.patch("/admin/groups/{group_id}", response_model=DaycareGroupResponse)
def update_daycare_group(
    group_id: UUID,
    data: DaycareGroupUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    group = db.query(DaycareGroup).filter(DaycareGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Daycare group not found")
    if data.name is not None:
        group.name = data.name
    if data.daycare_staff_id is not None:
        group.daycare_staff_id = UUID(data.daycare_staff_id)
    db.commit()
    db.refresh(group)
    return get_daycare_group(group_id, db, _)


@router.delete("/admin/groups/{group_id}")
def delete_daycare_group(
    group_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    group = db.query(DaycareGroup).filter(DaycareGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Daycare group not found")
    db.delete(group)
    db.commit()
    return {"message": "Daycare group deleted"}


@router.post("/admin/groups/{group_id}/students")
def add_student_to_daycare_group(
    group_id: UUID,
    data: DaycareGroupStudentCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    group = db.query(DaycareGroup).filter(DaycareGroup.id == group_id).first()
    if not group:
        raise HTTPException(status_code=404, detail="Daycare group not found")
    existing = db.query(DaycareGroupStudent).filter(
        DaycareGroupStudent.group_id == group_id,
        DaycareGroupStudent.student_id == UUID(data.student_id),
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Student already in group")
    gs = DaycareGroupStudent(group_id=group_id, student_id=UUID(data.student_id))
    db.add(gs)
    db.commit()
    return {"message": "Student added", "id": str(gs.id)}


@router.delete("/admin/groups/{group_id}/students/{student_id}")
def remove_student_from_daycare_group(
    group_id: UUID,
    student_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    gs = db.query(DaycareGroupStudent).filter(
        DaycareGroupStudent.group_id == group_id,
        DaycareGroupStudent.student_id == student_id,
    ).first()
    if not gs:
        raise HTTPException(status_code=404, detail="Student not in group")
    db.delete(gs)
    db.commit()
    return {"message": "Student removed"}


# ==================== DAYCARE STAFF: Daily Updates ====================


@router.post("/updates", response_model=DaycareDailyUpdateResponse)
async def create_daily_update(
    student_id: str = Form(...),
    date_str: str = Form(...),
    content: str = Form(...),
    photo: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Daycare staff posts a daily update for a student in their group."""
    if current_user.role != "daycare":
        raise HTTPException(status_code=403, detail="Only daycare staff can post daily updates")
    allowed = _daycare_staff_student_ids(db, current_user)
    if UUID(student_id) not in allowed:
        raise HTTPException(status_code=403, detail="You can only post updates for students in your group")
    try:
        update_date = date.fromisoformat(date_str.strip())
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date. Use YYYY-MM-DD")
    content = (content or "").strip()
    if not content:
        raise HTTPException(status_code=400, detail="Content is required")
    photo_path = None
    if photo and photo.filename:
        ext = os.path.splitext(photo.filename)[1] or ".jpg"
        fn = f"{uuid.uuid4()}{ext}"
        fp = os.path.join(DAYCARE_UPDATE_DIR, fn)
        with open(fp, "wb") as f:
            f.write(await photo.read())
        photo_path = fp
    update = DaycareDailyUpdate(
        student_id=UUID(student_id),
        author_id=current_user.id,
        date=update_date,
        content=content,
        photo_path=photo_path,
    )
    db.add(update)
    db.commit()
    db.refresh(update)
    student = db.query(Student).filter(Student.id == update.student_id).first()
    return DaycareDailyUpdateResponse(
        id=str(update.id),
        student_id=str(update.student_id),
        student_name=student.name if student else None,
        author_id=str(update.author_id),
        author_name=current_user.full_name,
        date=update.date.isoformat(),
        content=update.content,
        photo_path=update.photo_path,
        created_at=update.created_at.isoformat() if update.created_at else "",
    )


@router.get("/updates", response_model=list[DaycareDailyUpdateResponse])
def list_my_updates(
    student_id: Optional[str] = None,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Daycare staff lists daily updates they posted (for their group students)."""
    if current_user.role != "daycare":
        raise HTTPException(status_code=403, detail="Only daycare staff can access")
    allowed = _daycare_staff_student_ids(db, current_user)
    if not allowed:
        return []
    q = db.query(DaycareDailyUpdate).filter(DaycareDailyUpdate.student_id.in_(allowed))
    if student_id:
        sid = UUID(student_id)
        if sid not in allowed:
            raise HTTPException(status_code=403, detail="Student not in your group")
        q = q.filter(DaycareDailyUpdate.student_id == sid)
    if from_date:
        try:
            q = q.filter(DaycareDailyUpdate.date >= date.fromisoformat(from_date))
        except ValueError:
            pass
    if to_date:
        try:
            q = q.filter(DaycareDailyUpdate.date <= date.fromisoformat(to_date))
        except ValueError:
            pass
    updates = q.order_by(desc(DaycareDailyUpdate.date), desc(DaycareDailyUpdate.created_at)).limit(100).all()
    result = []
    for u in updates:
        student = db.query(Student).filter(Student.id == u.student_id).first()
        author = db.query(User).filter(User.id == u.author_id).first()
        result.append(DaycareDailyUpdateResponse(
            id=str(u.id),
            student_id=str(u.student_id),
            student_name=student.name if student else None,
            author_id=str(u.author_id),
            author_name=author.full_name if author else None,
            date=u.date.isoformat(),
            content=u.content,
            photo_path=u.photo_path,
            created_at=u.created_at.isoformat() if u.created_at else "",
        ))
    return result


@router.get("/my-students")
def get_my_students(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Daycare staff gets list of students in their group(s)."""
    if current_user.role != "daycare":
        raise HTTPException(status_code=403, detail="Only daycare staff can access")
    groups = db.query(DaycareGroup).filter(DaycareGroup.daycare_staff_id == current_user.id).all()
    seen = set()
    students = []
    for g in groups:
        branch = db.query(Branch).filter(Branch.id == g.branch_id).first()
        for gs in g.students:
            s = gs.student
            if s.id not in seen:
                seen.add(s.id)
                students.append({
                    "id": str(s.id),
                    "name": s.name,
                    "admission_number": s.admission_number,
                    "branch_name": branch.name if branch else None,
                })
    return {"students": students}


def _resolve_user(db: Session, current_user: Optional[User], token: Optional[str]) -> User:
    if current_user:
        return current_user
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    payload = decode_access_token(token)
    user_id = payload.get("sub") if payload else None
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    user = db.query(User).filter(User.id == UUID(user_id)).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


@router.get("/updates/{update_id}/photo")
def get_update_photo(
    update_id: UUID,
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Serve daycare daily update photo. Daycare staff and parents of the student can access."""
    user = _resolve_user(db, current_user, token)
    update = db.query(DaycareDailyUpdate).filter(DaycareDailyUpdate.id == update_id).first()
    if not update or not update.photo_path:
        raise HTTPException(status_code=404, detail="Photo not found")
    if user.role == "daycare":
        allowed = _daycare_staff_student_ids(db, user)
        if update.student_id not in allowed:
            raise HTTPException(status_code=403, detail="Not your student")
    elif user.role == "parent":
        links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == user.id).all()
        child_ids = [l.student_id for l in links]
        if update.student_id not in child_ids:
            raise HTTPException(status_code=403, detail="Not your child")
    else:
        raise HTTPException(status_code=403, detail="Access denied")
    if not os.path.exists(update.photo_path):
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(path=update.photo_path, media_type="image/jpeg")


# ==================== PARENT: View Daily Updates ====================


@router.get("/parent/updates", response_model=list[DaycareDailyUpdateResponse])
def parent_list_daily_updates(
    student_id: Optional[str] = None,
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Parents view daily updates for their linked children."""
    if current_user.role != "parent":
        raise HTTPException(status_code=403, detail="Only parents can access")
    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == current_user.id).all()
    child_ids = [l.student_id for l in links]
    if not child_ids:
        return []
    if student_id:
        sid = UUID(student_id)
        if sid not in child_ids:
            raise HTTPException(status_code=403, detail="Not your child")
        child_ids = [sid]
    q = db.query(DaycareDailyUpdate).filter(DaycareDailyUpdate.student_id.in_(child_ids))
    if from_date:
        try:
            q = q.filter(DaycareDailyUpdate.date >= date.fromisoformat(from_date))
        except ValueError:
            pass
    if to_date:
        try:
            q = q.filter(DaycareDailyUpdate.date <= date.fromisoformat(to_date))
        except ValueError:
            pass
    updates = q.order_by(desc(DaycareDailyUpdate.date), desc(DaycareDailyUpdate.created_at)).limit(100).all()
    result = []
    for u in updates:
        student = db.query(Student).filter(Student.id == u.student_id).first()
        author = db.query(User).filter(User.id == u.author_id).first()
        result.append(DaycareDailyUpdateResponse(
            id=str(u.id),
            student_id=str(u.student_id),
            student_name=student.name if student else None,
            author_id=str(u.author_id),
            author_name=author.full_name if author else None,
            date=u.date.isoformat(),
            content=u.content,
            photo_path=u.photo_path,
            created_at=u.created_at.isoformat() if u.created_at else "",
        ))
    return result
