import os
import uuid
import logging
from datetime import datetime, date
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Query, Body
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import get_current_user, get_optional_user
from app.core.security import decode_access_token
from app.models.user import User
from app.models.student import Student, ParentStudentLink
from app.models.branch import Class, BranchAssignment
from app.models.syllabus import Syllabus, Homework, GalleryImage
from app.models.syllabus_holiday import SyllabusHoliday
from app.schemas.syllabus import (
    SyllabusResponse,
    SyllabusUpdate,
    SyllabusCalendarResponse,
    SyllabusCalendarDay,
    SyllabusHolidayCreate,
    SyllabusHolidayCreateRange,
    SyllabusHolidayResponse,
    HomeworkResponse,
    HomeworkUpdate,
    GalleryResponse,
)
from app.services.academic_calendar_service import (
    get_academic_year_for_date,
    get_academic_year_str,
    academic_year_start,
    get_school_days_with_dates,
)
from app.services.notification_service import send_syllabus_notification, send_homework_notification

router = APIRouter(tags=["syllabus-homework"])
logger = logging.getLogger(__name__)

# Directory for file uploads
UPLOAD_DIR = "uploads"
SYLLABUS_DIR = os.path.join(UPLOAD_DIR, "syllabus")
HOMEWORK_DIR = os.path.join(UPLOAD_DIR, "homework")
GALLERY_DIR = os.path.join(UPLOAD_DIR, "gallery")

# Ensure directories exist
os.makedirs(SYLLABUS_DIR, exist_ok=True)
os.makedirs(HOMEWORK_DIR, exist_ok=True)
os.makedirs(GALLERY_DIR, exist_ok=True)


def _get_holiday_dates(db: Session, start_year: int, branch_id: UUID | None = None) -> set:
    """Get set of holiday dates for an academic year, optionally branch-scoped."""
    june1 = date(start_year, 6, 1)
    rows = db.query(SyllabusHoliday).filter(
        SyllabusHoliday.academic_year_start == june1,
        (SyllabusHoliday.branch_id.is_(None)) | (SyllabusHoliday.branch_id == branch_id),
    ).all()
    return {r.holiday_date for r in rows}


def _get_user_classes(db: Session, user: User) -> List[UUID]:
    """Get the list of class IDs a user has access to."""
    if user.role == "admin":
        return None  # Admin has access to all classes
    
    if user.role == "coordinator":
        # Coordinators can access all classes in their assigned branch
        assignments = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == user.id,
            BranchAssignment.branch_id.isnot(None)
        ).all()
        
        if not assignments:
            return []
        
        # Get all classes from the coordinator's branch(es)
        branch_ids = [a.branch_id for a in assignments]
        classes = db.query(Class).filter(Class.branch_id.in_(branch_ids)).all()
        return [c.id for c in classes]
    
    # For teachers, get specific class assignments
    assignments = db.query(BranchAssignment).filter(
        BranchAssignment.user_id == user.id,
        BranchAssignment.class_id.isnot(None)
    ).all()
    
    return [a.class_id for a in assignments]


def _can_upload_to_class(db: Session, user: User, class_id: UUID) -> bool:
    """Check if user can upload to a specific class."""
    if user.role == "admin":
        return True
    
    if user.role in ["teacher", "coordinator"]:
        user_classes = _get_user_classes(db, user)
        return class_id in user_classes if user_classes else False
    
    return False


def _can_view_class(db: Session, user: User, class_id: UUID) -> bool:
    """Check if user can view content for a specific class."""
    if user.role in ["admin", "coordinator", "toddlers", "daycare"]:
        return True

    if user.role == "teacher":
        user_classes = _get_user_classes(db, user)
        return class_id in user_classes if user_classes else False
    
    if user.role == "parent":
        # Parents can view content for their children's classes
        parent_links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == user.id).all()
        student_ids = [link.student_id for link in parent_links]
        if student_ids:
            children = db.query(Student).filter(Student.id.in_(student_ids)).all()
            children_class_ids = [child.class_id for child in children if child.class_id]
            return class_id in children_class_ids
        return False

    return False


def _resolve_request_user(db: Session, current_user: Optional[User], token: Optional[str]) -> User:
    if current_user:
        return current_user

    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")

    payload = decode_access_token(token)
    user_id = payload.get("sub") if payload else None
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

    user = db.query(User).filter(User.id == UUID(user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    return user


async def _save_file(file: UploadFile, directory: str) -> tuple[str, str, str]:
    """Save uploaded file and return (file_path, file_name, file_size)."""
    from app.services.media_files import save_upload_file

    file_path, file_name, file_size, _mime = await save_upload_file(file, directory)
    return file_path, file_name, file_size


# ========== SYLLABUS ENDPOINTS ==========

@router.get("/syllabus/grades", response_model=List[str])
def list_grade_names(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List unique class/grade names across all branches. Admin only."""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin only")
    rows = db.query(Class.name).distinct().order_by(Class.name).all()
    return [r[0] for r in rows]

@router.post("/syllabus/upload", response_model=SyllabusResponse)
async def upload_syllabus(
    class_id: Optional[UUID] = Form(None),
    class_name: Optional[str] = Form(None),
    title: str = Form(...),
    school_day: int = Form(...),
    academic_year_start_str: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload syllabus for a specific school day (1-180). Use class_id for single class, or class_name for all branches grade-wise (admin only)."""
    if school_day < 1 or school_day > 180:
        raise HTTPException(status_code=400, detail="school_day must be between 1 and 180")
    if not class_id and not class_name:
        raise HTTPException(status_code=400, detail="Provide class_id or class_name")
    if class_id and class_name:
        raise HTTPException(status_code=400, detail="Provide either class_id or class_name, not both")

    if academic_year_start_str:
        try:
            ay_start = datetime.fromisoformat(academic_year_start_str).date()
            if ay_start.month != 6 or ay_start.day != 1:
                raise HTTPException(status_code=400, detail="academic_year_start must be June 1 (YYYY-06-01)")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid academic_year_start format")
    else:
        start_year, _ = get_academic_year_for_date(date.today())
        ay_start = academic_year_start(start_year)

    if class_name:
        if current_user.role != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Grade-wise upload for all branches is admin only")
        target_classes = db.query(Class).filter(Class.name == class_name).all()
        if not target_classes:
            raise HTTPException(status_code=404, detail=f"No classes found with name '{class_name}'")
        for c in target_classes:
            if not _can_upload_to_class(db, current_user, c.id):
                raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"You don't have permission to upload for {c.name}")
    else:
        if not _can_upload_to_class(db, current_user, class_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You don't have permission to upload syllabus for this class"
            )
        class_ = db.query(Class).filter(Class.id == class_id).first()
        if not class_:
            raise HTTPException(status_code=404, detail="Class not found")
        target_classes = [class_]

    file_path, file_name, file_size = await _save_file(file, SYLLABUS_DIR)
    syllabi_created = []
    for class_ in target_classes:
        syllabus = Syllabus(
            class_id=class_.id,
            uploaded_by=current_user.id,
            title=title,
            description=description,
            school_day=school_day,
            academic_year_start=ay_start,
            file_path=file_path,
            file_name=file_name,
            file_size=file_size,
        )
        db.add(syllabus)
        syllabi_created.append((syllabus, class_))
    db.commit()

    for syllabus, class_ in syllabi_created:
        db.refresh(syllabus)
        try:
            send_syllabus_notification(syllabus, db)
        except Exception as ex:
            logger.error(f"Failed to send syllabus notification for syllabus {syllabus.id}: {str(ex)}")

    last_syllabus, last_class = syllabi_created[-1]
    return SyllabusResponse(
        id=last_syllabus.id,
        class_id=last_syllabus.class_id,
        uploaded_by=last_syllabus.uploaded_by,
        uploader_name=current_user.full_name,
        title=last_syllabus.title,
        description=last_syllabus.description,
        upload_date=None,
        school_day=last_syllabus.school_day,
        academic_year_start=last_syllabus.academic_year_start,
        file_path=last_syllabus.file_path,
        file_name=last_syllabus.file_name,
        file_size=last_syllabus.file_size,
        class_name=last_class.name,
        created_at=last_syllabus.created_at.isoformat() if last_syllabus.created_at else "",
    )


@router.get("/syllabus", response_model=List[SyllabusResponse])
def list_syllabus(
    class_id: Optional[UUID] = None,
    school_day: Optional[int] = None,
    academic_year_start_str: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List syllabus (filtered by class, school_day, academic_year)."""
    query = db.query(Syllabus)
    if class_id:
        if not _can_view_class(db, current_user, class_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You don't have permission to view this class"
            )
        query = query.filter(Syllabus.class_id == class_id)
    else:
        if current_user.role == "teacher":
            user_classes = _get_user_classes(db, current_user)
            if user_classes:
                query = query.filter(Syllabus.class_id.in_(user_classes))
            else:
                return []
        elif current_user.role in ["toddlers", "daycare"]:
            pass
    if current_user.role in ["teacher", "coordinator"]:
        admin_ids = db.query(User.id).filter(User.role == "admin").subquery()
        query = query.filter(Syllabus.uploaded_by.in_(admin_ids))
    if school_day is not None:
        query = query.filter(Syllabus.school_day == school_day)
    if academic_year_start_str:
        ay_start = datetime.fromisoformat(academic_year_start_str).date()
        query = query.filter(Syllabus.academic_year_start == ay_start)
    else:
        start_year, _ = get_academic_year_for_date(date.today())
        ay_start = academic_year_start(start_year)
        query = query.filter(Syllabus.academic_year_start == ay_start)
    syllabi = query.order_by(Syllabus.school_day.asc()).all()
    result = []
    for s in syllabi:
        class_ = db.query(Class).filter(Class.id == s.class_id).first()
        uploader = db.query(User).filter(User.id == s.uploaded_by).first()
        result.append(SyllabusResponse(
            id=s.id,
            class_id=s.class_id,
            uploaded_by=s.uploaded_by,
            uploader_name=uploader.full_name if uploader else None,
            title=s.title,
            description=s.description,
            upload_date=s.upload_date,
            school_day=s.school_day,
            academic_year_start=s.academic_year_start,
            file_path=s.file_path,
            file_name=s.file_name,
            file_size=s.file_size,
            class_name=class_.name if class_ else "",
            created_at=s.created_at.isoformat() if s.created_at else "",
        ))
    return result


@router.get("/syllabus/calendar", response_model=SyllabusCalendarResponse)
def get_syllabus_calendar(
    class_id: UUID = Query(...),
    academic_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get Day 1-180 with dates and syllabus for each day. Dates shift with holidays."""
    if not _can_view_class(db, current_user, class_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to view this class"
        )
    class_ = db.query(Class).filter(Class.id == class_id).first()
    if not class_:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Class not found")
    start_year = academic_year if academic_year else get_academic_year_for_date(date.today())[0]
    ay_start = academic_year_start(start_year)
    holiday_dates = _get_holiday_dates(db, start_year, class_.branch_id)
    days_data = get_school_days_with_dates(start_year, holiday_dates)
    syllabi_by_day = {}
    query = db.query(Syllabus).filter(
        Syllabus.class_id == class_id,
        Syllabus.academic_year_start == ay_start,
        Syllabus.school_day.isnot(None),
    )
    if current_user.role in ["teacher", "coordinator"]:
        admin_ids = db.query(User.id).filter(User.role == "admin").subquery()
        query = query.filter(Syllabus.uploaded_by.in_(admin_ids))
    for s in query.all():
        d = s.school_day
        if d not in syllabi_by_day:
            syllabi_by_day[d] = []
        uploader = db.query(User).filter(User.id == s.uploaded_by).first()
        syllabi_by_day[d].append({
            "id": str(s.id),
            "title": s.title,
            "file_name": s.file_name,
            "uploader_name": uploader.full_name if uploader else None,
        })
    result_days = [
        SyllabusCalendarDay(day=item["day"], date=item["date"], syllabus=syllabi_by_day.get(item["day"], []))
        for item in days_data
    ]
    return SyllabusCalendarResponse(
        academic_year_start=ay_start.isoformat(),
        academic_year_str=get_academic_year_str(ay_start),
        days=result_days,
    )


@router.post("/syllabus/holidays", response_model=SyllabusHolidayResponse)
def add_syllabus_holiday(
    data: SyllabusHolidayCreate = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Add a single holiday date. Admin only."""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only admins can add holidays")
    start_year, _ = get_academic_year_for_date(data.holiday_date)
    ay_start = academic_year_start(start_year)
    existing = db.query(SyllabusHoliday).filter(
        SyllabusHoliday.academic_year_start == ay_start,
        SyllabusHoliday.holiday_date == data.holiday_date,
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Holiday already exists for this date")
    h = SyllabusHoliday(
        academic_year_start=ay_start,
        holiday_date=data.holiday_date,
        reason=data.reason,
        created_by=current_user.id,
    )
    db.add(h)
    db.commit()
    db.refresh(h)
    return SyllabusHolidayResponse(
        id=h.id,
        academic_year_start=h.academic_year_start,
        holiday_date=h.holiday_date,
        reason=h.reason,
        created_at=h.created_at.isoformat() if h.created_at else "",
    )


@router.post("/syllabus/holidays/range", response_model=List[SyllabusHolidayResponse])
def add_syllabus_holiday_range(
    data: SyllabusHolidayCreateRange = Body(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Add holiday for N days starting from a date. Admin only."""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only admins can add holidays")
    from datetime import timedelta
    result = []
    current = data.start_date
    for _ in range(data.num_days):
        start_year, _ = get_academic_year_for_date(current)
        ay_start = academic_year_start(start_year)
        existing = db.query(SyllabusHoliday).filter(
            SyllabusHoliday.academic_year_start == ay_start,
            SyllabusHoliday.holiday_date == current,
        ).first()
        if not existing:
            h = SyllabusHoliday(
                academic_year_start=ay_start,
                holiday_date=current,
                reason=data.reason,
                created_by=current_user.id,
            )
            db.add(h)
            db.commit()
            db.refresh(h)
            result.append(SyllabusHolidayResponse(
                id=h.id,
                academic_year_start=h.academic_year_start,
                holiday_date=h.holiday_date,
                reason=h.reason,
                created_at=h.created_at.isoformat() if h.created_at else "",
            ))
        current += timedelta(days=1)
    return result


@router.get("/syllabus/holidays", response_model=List[SyllabusHolidayResponse])
def list_syllabus_holidays(
    academic_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List holidays for an academic year."""
    start_year = academic_year if academic_year else get_academic_year_for_date(date.today())[0]
    ay_start = academic_year_start(start_year)
    rows = db.query(SyllabusHoliday).filter(
        SyllabusHoliday.academic_year_start == ay_start
    ).order_by(SyllabusHoliday.holiday_date).all()
    return [
        SyllabusHolidayResponse(
            id=r.id,
            academic_year_start=r.academic_year_start,
            holiday_date=r.holiday_date,
            reason=r.reason,
            created_at=r.created_at.isoformat() if r.created_at else "",
        )
        for r in rows
    ]


@router.get("/syllabus/{syllabus_id}", response_model=SyllabusResponse)
def get_syllabus(
    syllabus_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a specific syllabus."""
    syllabus = db.query(Syllabus).filter(Syllabus.id == syllabus_id).first()
    if not syllabus:
        raise HTTPException(status_code=404, detail="Syllabus not found")
    
    # Check authorization
    if not _can_view_class(db, current_user, syllabus.class_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to view this syllabus"
        )
    
    class_ = db.query(Class).filter(Class.id == syllabus.class_id).first()
    uploader = db.query(User).filter(User.id == syllabus.uploaded_by).first()

    if current_user.role in ["teacher", "coordinator"] and (uploader is None or uploader.role != "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view syllabus uploaded by admin"
        )

    return SyllabusResponse(
        id=syllabus.id,
        class_id=syllabus.class_id,
        uploaded_by=syllabus.uploaded_by,
        uploader_name=uploader.full_name if uploader else None,
        title=syllabus.title,
        description=syllabus.description,
        upload_date=syllabus.upload_date,
        school_day=syllabus.school_day,
        academic_year_start=syllabus.academic_year_start,
        file_path=syllabus.file_path,
        file_name=syllabus.file_name,
        file_size=syllabus.file_size,
        class_name=class_.name if class_ else "",
        created_at=syllabus.created_at.isoformat() if syllabus.created_at else "",
    )


@router.put("/syllabus/{syllabus_id}", response_model=SyllabusResponse)
def update_syllabus(
    syllabus_id: UUID,
    data: SyllabusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update syllabus metadata (admin or uploader only)."""
    syllabus = db.query(Syllabus).filter(Syllabus.id == syllabus_id).first()
    if not syllabus:
        raise HTTPException(status_code=404, detail="Syllabus not found")
    
    # Only admin or the uploader can update
    if current_user.role != "admin" and syllabus.uploaded_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to update this syllabus"
        )
    
    if data.title:
        syllabus.title = data.title
    if data.description is not None:
        syllabus.description = data.description
    if data.school_day is not None:
        if data.school_day < 1 or data.school_day > 180:
            raise HTTPException(status_code=400, detail="school_day must be between 1 and 180")
        syllabus.school_day = data.school_day
    db.commit()
    db.refresh(syllabus)
    
    class_ = db.query(Class).filter(Class.id == syllabus.class_id).first()
    uploader = db.query(User).filter(User.id == syllabus.uploaded_by).first()
    
    return SyllabusResponse(
        id=syllabus.id,
        class_id=syllabus.class_id,
        uploaded_by=syllabus.uploaded_by,
        uploader_name=uploader.full_name if uploader else None,
        title=syllabus.title,
        description=syllabus.description,
        upload_date=syllabus.upload_date,
        file_path=syllabus.file_path,
        file_name=syllabus.file_name,
        file_size=syllabus.file_size,
        class_name=class_.name if class_ else "",
        created_at=syllabus.created_at.isoformat() if syllabus.created_at else "",
    )


@router.delete("/syllabus/{syllabus_id}")
def delete_syllabus(
    syllabus_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete syllabus (admin only)."""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins can delete syllabus"
        )

    syllabus = db.query(Syllabus).filter(Syllabus.id == syllabus_id).first()
    if not syllabus:
        raise HTTPException(status_code=404, detail="Syllabus not found")

    # Delete file
    if os.path.exists(syllabus.file_path):
        os.remove(syllabus.file_path)

    db.delete(syllabus)
    db.commit()

    return {"message": "Syllabus deleted successfully"}


@router.get("/syllabus/{syllabus_id}/file")
def view_syllabus_file(
    syllabus_id: UUID,
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """View/download syllabus file."""
    user = _resolve_request_user(db, current_user, token)

    syllabus = db.query(Syllabus).filter(Syllabus.id == syllabus_id).first()
    if not syllabus:
        raise HTTPException(status_code=404, detail="Syllabus not found")

    if not _can_view_class(db, user, syllabus.class_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You don't have permission to view this syllabus")

    uploader = db.query(User).filter(User.id == syllabus.uploaded_by).first()
    if user.role in ["teacher", "coordinator"] and (uploader is None or uploader.role != "admin"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only view syllabus uploaded by admin")

    if not os.path.exists(syllabus.file_path):
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(path=syllabus.file_path, filename=syllabus.file_name, media_type="application/octet-stream")


# ========== HOMEWORK ENDPOINTS ==========

@router.post("/homework/upload", response_model=HomeworkResponse)
async def upload_homework(
    class_id: UUID = Form(...),
    title: str = Form(...),
    upload_date: str = Form(...),
    due_date: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload homework (admin or teacher for their class)."""
    # Check authorization
    if not _can_upload_to_class(db, current_user, class_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to upload homework for this class"
        )
    
    # Verify class exists
    class_ = db.query(Class).filter(Class.id == class_id).first()
    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")
    
    # Save file
    file_path, file_name, file_size = await _save_file(file, HOMEWORK_DIR)
    
    # Create homework record
    homework = Homework(
        class_id=class_id,
        uploaded_by=current_user.id,
        title=title,
        description=description,
        upload_date=datetime.fromisoformat(upload_date).date(),
        due_date=datetime.fromisoformat(due_date).date() if due_date else None,
        file_path=file_path,
        file_name=file_name,
        file_size=file_size,
    )
    
    db.add(homework)
    db.commit()
    db.refresh(homework)
    
    # Send notifications (Push and In-App)
    try:
        # 1. Push Notification
        send_homework_notification(homework, db)
        
        # 2. In-App Notification
        from app.services import messaging_service
        students = db.query(Student).filter(Student.class_id == homework.class_id).all()
        parent_user_ids = []
        for student in students:
            links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student.id).all()
            for link in links:
                parent_user_ids.append(link.user_id)
        
        if parent_user_ids:
            parent_user_ids = list(set(parent_user_ids))
            messaging_service.create_notifications_for_users(
                db, 
                parent_user_ids, 
                f"New Homework: {homework.title}", 
                f"Homework for {class_.name} has been assigned. Due date: {homework.due_date.strftime('%b %d, %Y') if homework.due_date else 'N/A'}",
                sender_id=current_user.id
            )
    except Exception as ex:
        logger.error(f"Failed to send homework notifications: {str(ex)}")
    
    return HomeworkResponse(
        id=homework.id,
        class_id=homework.class_id,
        uploaded_by=homework.uploaded_by,
        uploader_name=current_user.full_name,
        title=homework.title,
        description=homework.description,
        upload_date=homework.upload_date,
        due_date=homework.due_date,
        file_path=homework.file_path,
        file_name=homework.file_name,
        file_size=homework.file_size,
        class_name=class_.name,
        created_at=homework.created_at.isoformat() if homework.created_at else "",
    )


@router.get("/homework", response_model=List[HomeworkResponse])
def list_homework(
    class_id: Optional[UUID] = None,
    upload_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List homework (filtered by class and/or date)."""
    query = db.query(Homework)
    
    # Filter by class if specified
    if class_id:
        if not _can_view_class(db, current_user, class_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You don't have permission to view this class"
            )
        query = query.filter(Homework.class_id == class_id)
    else:
        # If no class specified, filter by user's accessible classes
        if current_user.role == "teacher":
            user_classes = _get_user_classes(db, current_user)
            if user_classes:
                query = query.filter(Homework.class_id.in_(user_classes))
            else:
                return []
        elif current_user.role == "parent":
            # Get all classes of parent's children
            parent_links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == current_user.id).all()
            student_ids = [link.student_id for link in parent_links]
            if student_ids:
                children = db.query(Student).filter(Student.id.in_(student_ids)).all()
                children_class_ids = [child.class_id for child in children if child.class_id]
                if children_class_ids:
                    query = query.filter(Homework.class_id.in_(children_class_ids))
                else:
                    return []
            else:
                return []
        elif current_user.role in ["toddlers", "daycare"]:
            pass  # see all homework
    
    # Coordinators/parents should see homework assigned to their class, regardless of who uploaded it.
    # We already filter by class_id above.
    
    # Filter by date if specified
    if upload_date:
        query = query.filter(Homework.upload_date == datetime.fromisoformat(upload_date).date())
    
    homeworks = query.order_by(Homework.upload_date.desc()).all()
    
    # Build response
    result = []
    for h in homeworks:
        class_ = db.query(Class).filter(Class.id == h.class_id).first()
        uploader = db.query(User).filter(User.id == h.uploaded_by).first()
        
        result.append(HomeworkResponse(
            id=h.id,
            class_id=h.class_id,
            uploaded_by=h.uploaded_by,
            uploader_name=uploader.full_name if uploader else None,
            title=h.title,
            description=h.description,
            upload_date=h.upload_date,
            due_date=h.due_date,
            file_path=h.file_path,
            file_name=h.file_name,
            file_size=h.file_size,
            class_name=class_.name if class_ else "",
            created_at=h.created_at.isoformat() if h.created_at else "",
        ))
    
    return result


@router.get("/homework/{homework_id}", response_model=HomeworkResponse)
def get_homework(
    homework_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get a specific homework."""
    homework = db.query(Homework).filter(Homework.id == homework_id).first()
    if not homework:
        raise HTTPException(status_code=404, detail="Homework not found")
    
    # Check authorization
    if not _can_view_class(db, current_user, homework.class_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to view this homework"
        )
    
    # Anyone with class view permission can see individual homework
    
    class_ = db.query(Class).filter(Class.id == homework.class_id).first()
    uploader = db.query(User).filter(User.id == homework.uploaded_by).first()
    
    return HomeworkResponse(
        id=homework.id,
        class_id=homework.class_id,
        uploaded_by=homework.uploaded_by,
        uploader_name=uploader.full_name if uploader else None,
        title=homework.title,
        description=homework.description,
        upload_date=homework.upload_date,
        due_date=homework.due_date,
        file_path=homework.file_path,
        file_name=homework.file_name,
        file_size=homework.file_size,
        class_name=class_.name if class_ else "",
        created_at=homework.created_at.isoformat() if homework.created_at else "",
    )


@router.put("/homework/{homework_id}", response_model=HomeworkResponse)
def update_homework(
    homework_id: UUID,
    data: HomeworkUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Update homework metadata (admin or uploader only)."""
    homework = db.query(Homework).filter(Homework.id == homework_id).first()
    if not homework:
        raise HTTPException(status_code=404, detail="Homework not found")
    
    # Only admin or the uploader can update
    if current_user.role != "admin" and homework.uploaded_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to update this homework"
        )
    
    # Update fields
    if data.title:
        homework.title = data.title
    if data.description is not None:
        homework.description = data.description
    if data.upload_date:
        homework.upload_date = data.upload_date
    if data.due_date is not None:
        homework.due_date = data.due_date
    
    db.commit()
    db.refresh(homework)
    
    class_ = db.query(Class).filter(Class.id == homework.class_id).first()
    uploader = db.query(User).filter(User.id == homework.uploaded_by).first()
    
    return HomeworkResponse(
        id=homework.id,
        class_id=homework.class_id,
        uploaded_by=homework.uploaded_by,
        uploader_name=uploader.full_name if uploader else None,
        title=homework.title,
        description=homework.description,
        upload_date=homework.upload_date,
        due_date=homework.due_date,
        file_path=homework.file_path,
        file_name=homework.file_name,
        file_size=homework.file_size,
        class_name=class_.name if class_ else "",
        created_at=homework.created_at.isoformat() if homework.created_at else "",
    )


@router.delete("/homework/{homework_id}")
def delete_homework(
    homework_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete homework (admin or uploader can delete)."""
    homework = db.query(Homework).filter(Homework.id == homework_id).first()
    if not homework:
        raise HTTPException(status_code=404, detail="Homework not found")
    
    # Only admin or the uploader can delete
    if current_user.role != "admin" and homework.uploaded_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to delete this homework"
        )
    
    # Delete file
    if os.path.exists(homework.file_path):
        os.remove(homework.file_path)
    
    db.delete(homework)
    db.commit()
    
    return {"message": "Homework deleted successfully"}


@router.get("/homework/{homework_id}/file")
def view_homework_file(
    homework_id: UUID,
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """View/download homework file."""
    user = _resolve_request_user(db, current_user, token)

    homework = db.query(Homework).filter(Homework.id == homework_id).first()
    if not homework:
        raise HTTPException(status_code=404, detail="Homework not found")

    if not _can_view_class(db, user, homework.class_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You don't have permission to view this homework")

    # Anyone with class view permission can see individual homework files

    if not os.path.exists(homework.file_path):
        raise HTTPException(status_code=404, detail="File not found")

    from app.services.media_files import mime_for_filename

    media = mime_for_filename(homework.file_name or "")
    return FileResponse(path=homework.file_path, filename=homework.file_name, media_type=media)


# ========== GALLERY ENDPOINTS ==========

@router.post("/gallery/upload", response_model=GalleryResponse)
async def upload_gallery_image(
    class_id: UUID = Form(...),
    upload_date: str = Form(...),
    title: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload a gallery image (admin/coordinator/teacher for accessible class)."""
    if current_user.role not in ["admin", "coordinator", "teacher"]:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only staff can upload gallery images")

    if not _can_upload_to_class(db, current_user, class_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to upload gallery images for this class",
        )

    class_ = db.query(Class).filter(Class.id == class_id).first()
    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Only image files are allowed for gallery")

    file_path, file_name, file_size = await _save_file(file, GALLERY_DIR)

    item = GalleryImage(
        class_id=class_id,
        uploaded_by=current_user.id,
        title=title,
        description=description,
        upload_date=datetime.fromisoformat(upload_date).date(),
        file_path=file_path,
        file_name=file_name,
        file_size=file_size,
    )

    db.add(item)
    db.commit()
    db.refresh(item)

    return GalleryResponse(
        id=item.id,
        class_id=item.class_id,
        uploaded_by=item.uploaded_by,
        uploader_name=current_user.full_name,
        title=item.title,
        description=item.description,
        upload_date=item.upload_date,
        file_name=item.file_name,
        file_path=item.file_path,
        file_size=item.file_size,
        class_name=class_.name,
        created_at=item.created_at.isoformat() if item.created_at else "",
    )


@router.get("/gallery", response_model=List[GalleryResponse])
def list_gallery(
    class_id: Optional[UUID] = None,
    upload_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List gallery images visible to current user. Parents only see children's classes."""
    query = db.query(GalleryImage)

    if class_id:
        if not _can_view_class(db, current_user, class_id):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You don't have permission to view this class")
        query = query.filter(GalleryImage.class_id == class_id)
    else:
        if current_user.role == "teacher":
            user_classes = _get_user_classes(db, current_user)
            if not user_classes:
                return []
            query = query.filter(GalleryImage.class_id.in_(user_classes))
        elif current_user.role == "coordinator":
            user_classes = _get_user_classes(db, current_user)
            if not user_classes:
                return []
            query = query.filter(GalleryImage.class_id.in_(user_classes))
        elif current_user.role == "parent":
            parent_links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == current_user.id).all()
            student_ids = [link.student_id for link in parent_links]
            if not student_ids:
                return []
            children = db.query(Student).filter(Student.id.in_(student_ids)).all()
            children_class_ids = [child.class_id for child in children if child.class_id]
            if not children_class_ids:
                return []
            query = query.filter(GalleryImage.class_id.in_(children_class_ids))
        elif current_user.role in ["toddlers", "daycare"]:
            pass  # see all gallery

    if upload_date:
        query = query.filter(GalleryImage.upload_date == datetime.fromisoformat(upload_date).date())

    items = query.order_by(GalleryImage.upload_date.desc(), GalleryImage.created_at.desc()).all()
    result = []
    for item in items:
        class_ = db.query(Class).filter(Class.id == item.class_id).first()
        uploader = db.query(User).filter(User.id == item.uploaded_by).first()
        result.append(
            GalleryResponse(
                id=item.id,
                class_id=item.class_id,
                uploaded_by=item.uploaded_by,
                uploader_name=uploader.full_name if uploader else None,
                title=item.title,
                description=item.description,
                upload_date=item.upload_date,
                file_name=item.file_name,
                file_path=item.file_path,
                file_size=item.file_size,
                class_name=class_.name if class_ else "",
                created_at=item.created_at.isoformat() if item.created_at else "",
            )
        )
    return result


@router.get("/gallery/{gallery_id}/file")
def view_gallery_file(
    gallery_id: UUID,
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """View/download gallery image file."""
    user = _resolve_request_user(db, current_user, token)

    item = db.query(GalleryImage).filter(GalleryImage.id == gallery_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Gallery image not found")

    if not _can_view_class(db, user, item.class_id):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You don't have permission to view this image")

    if not os.path.exists(item.file_path):
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(path=item.file_path, filename=item.file_name, media_type="application/octet-stream")
