import os
from uuid import UUID
from datetime import datetime, date
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.core.auth import require_admin, get_current_user
from app.models import User, LearningModule, LearningVideo, LearningModuleAssignment
from app.models import Student, Class, BranchAssignment
from app.models.syllabus_holiday import SyllabusHoliday
from app.services.media_files import save_upload_file
from app.services.academic_calendar_service import (
    get_academic_year_for_date,
    academic_year_start,
    get_school_days_with_dates,
)

router = APIRouter(prefix="/learning-modules", tags=["learning-modules"])
MIN_VIDEO_BYTES = 1024


@router.get("/")
def list_modules(db: Session = Depends(get_db)):
    """List all learning modules (public access)."""
    modules = db.query(LearningModule).all()
    return [
        {
            "id": str(m.id),
            "name": m.name,
            "description": m.description,
            "created_at": m.created_at.isoformat() if m.created_at else None,
            "video_count": len(m.videos),
        }
        for m in modules
    ]


@router.get("/{module_id}/videos")
def list_module_videos(module_id: UUID, db: Session = Depends(get_db)):
    """List all videos in a learning module (public access)."""
    module = db.query(LearningModule).filter(LearningModule.id == str(module_id)).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")

    return [
        {
            "id": str(v.id),
            "title": v.title,
            "description": v.description,
            "duration": v.duration,
            "file_path": v.file_path,
            "created_at": v.created_at.isoformat() if v.created_at else None,
        }
        for v in module.videos
    ]


@router.post("/")
def create_module(
    name: str = Form(...),
    description: str = Form(None),
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Create a new learning module (admin only)."""
    module = LearningModule(
        name=name,
        description=description,
        created_by=user.id,
    )
    db.add(module)
    db.commit()
    db.refresh(module)

    return {
        "id": str(module.id),
        "name": module.name,
        "description": module.description,
        "created_at": module.created_at.isoformat() if module.created_at else None,
    }


@router.post("/{module_id}/videos/upload")
async def upload_video(
    module_id: UUID,
    title: str = Form(...),
    description: str = Form(None),
    school_day: Optional[int] = Form(None),
    academic_year_start_str: Optional[str] = Form(None),
    file: UploadFile = File(...),
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Upload a video to a learning module (admin only)."""
    # Check module exists
    module = db.query(LearningModule).filter(LearningModule.id == str(module_id)).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")

    # Save file
    try:
        saved_path, original_name, size_label, mime = await save_upload_file(file, "uploads/learning-videos/")
        # Extract bytes from size_label or get from file size on disk
        file_size = os.path.getsize(saved_path) if os.path.exists(saved_path) else 0
        if file_size < MIN_VIDEO_BYTES:
            if os.path.exists(saved_path):
                os.remove(saved_path)
            raise HTTPException(
                status_code=400,
                detail="Invalid video file. Please upload a real video, not a placeholder file.",
            )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to save file: {str(e)}")

    # Create database record
    ay_start = None
    if academic_year_start_str:
        try:
            ay = datetime.fromisoformat(academic_year_start_str).date()
            if ay.month != 6 or ay.day != 1:
                raise HTTPException(status_code=400, detail="academic_year_start must be June 1 (YYYY-06-01)")
            ay_start = ay
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid academic_year_start format")
    else:
        start_year, _ = get_academic_year_for_date(date.today())
        ay_start = academic_year_start(start_year)

    if school_day is not None:
        if school_day < 1 or school_day > 180:
            raise HTTPException(status_code=400, detail="school_day must be between 1 and 180")

    video = LearningVideo(
        module_id=module.id,
        title=title,
        description=description,
        file_path=saved_path,
        file_name=original_name,
        file_size=file_size,
        duration=None,
        school_day=school_day,
        academic_year_start=ay_start,
    )
    db.add(video)
    db.commit()
    db.refresh(video)

    return {
        "id": str(video.id),
        "module_id": str(video.module_id),
        "title": video.title,
        "description": video.description,
        "file_path": video.file_path,
        "file_name": video.file_name,
        "file_size": video.file_size,
        "created_at": video.created_at.isoformat() if video.created_at else None,
    }


@router.delete("/{module_id}")
def delete_module(
    module_id: UUID,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Delete a learning module and all its videos (admin only)."""
    module = db.query(LearningModule).filter(LearningModule.id == str(module_id)).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")

    db.delete(module)
    db.commit()

    return {"message": "Module deleted successfully"}




@router.get("/for-student/{student_id}")
def list_modules_for_student(student_id: str, db: Session = Depends(get_db)):
    """List learning modules assigned to student's class/branch."""
    from sqlalchemy import or_

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    class_id = str(student.class_id) if student.class_id else None
    branch_id = str(student.branch_id) if student.branch_id else None

    if not class_id and not branch_id:
        return []

    conditions = []
    if class_id:
        conditions.append(LearningModuleAssignment.class_id == class_id)
    if branch_id:
        conditions.append(LearningModuleAssignment.branch_id == branch_id)

    assignments = db.query(LearningModuleAssignment).filter(or_(*conditions)).all()

    seen = set()
    module_ids = []
    for a in assignments:
        mid = str(a.module_id)
        if mid not in seen:
            seen.add(mid)
            module_ids.append(mid)

    if not module_ids:
        return []

    modules = db.query(LearningModule).filter(LearningModule.id.in_(module_ids)).all()

    return [
        {
            "id": str(m.id),
            "name": m.name,
            "description": m.description,
            "created_at": m.created_at.isoformat() if m.created_at else None,
            "video_count": len(m.videos),
        }
        for m in modules
    ]


@router.get("/class-calendar")
def get_class_calendar(
    class_id: UUID = Query(...),
    academic_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get Day 1-180 calendar for a class, aggregating videos from all assigned modules."""
    class_ = db.query(Class).filter(Class.id == class_id).first()
    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    if current_user.role not in ("admin", "coordinator"):
        if current_user.role == "teacher":
            assignments = db.query(BranchAssignment).filter(
                BranchAssignment.user_id == current_user.id,
                BranchAssignment.class_id.isnot(None)
            ).all()
            user_class_ids = [a.class_id for a in assignments]
            if class_id not in user_class_ids:
                raise HTTPException(status_code=403, detail="You don't have permission to view this class")
        elif current_user.role == "parent":
            from app.models.student import Student, ParentStudentLink
            links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == current_user.id).all()
            student_ids = [l.student_id for l in links]
            children = db.query(Student).filter(Student.id.in_(student_ids)).all() if student_ids else []
            children_class_ids = [c.class_id for c in children if c.class_id]
            if class_id not in children_class_ids:
                raise HTTPException(status_code=403, detail="You don't have permission to view this class")
        else:
            raise HTTPException(status_code=403, detail="You don't have permission to view this class")

    start_year = academic_year if academic_year else get_academic_year_for_date(date.today())[0]
    ay_start = academic_year_start(start_year)

    rows = db.query(SyllabusHoliday).filter(
        SyllabusHoliday.academic_year_start == ay_start,
        (SyllabusHoliday.branch_id.is_(None)) | (SyllabusHoliday.branch_id == class_.branch_id),
    ).all()
    holiday_dates = {r.holiday_date for r in rows}
    days_data = get_school_days_with_dates(start_year, holiday_dates)

    # Find all module IDs assigned to this class or its branch
    class_assignments = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.class_id == str(class_id)
    ).all()
    branch_assignments = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.branch_id == str(class_.branch_id)
    ).all() if class_.branch_id else []

    module_ids = list({str(a.module_id) for a in class_assignments + branch_assignments})

    videos_by_day = {}
    if module_ids:
        videos = db.query(LearningVideo).filter(
            LearningVideo.module_id.in_(module_ids),
            LearningVideo.school_day.isnot(None),
            LearningVideo.academic_year_start == ay_start,
        ).all()
        for v in videos:
            d = v.school_day
            if d not in videos_by_day:
                videos_by_day[d] = []
            videos_by_day[d].append({
                "id": str(v.id),
                "title": v.title,
                "file_path": v.file_path,
                "file_name": v.file_name,
                "subject_name": v.subject_name,
            })

    result_days = [
        {"day": item["day"], "date": item["date"], "videos": videos_by_day.get(item["day"], [])}
        for item in days_data
    ]

    return {
        "academic_year_start": ay_start.isoformat(),
        "academic_year_str": f"{start_year}-{str(start_year+1)[2:]}",
        "days": result_days,
    }


@router.post("/class-upload")
async def upload_video_for_class(
    class_id: str = Form(...),
    school_day: int = Form(...),
    title: str = Form(...),
    subject_name: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    academic_year_start_str: Optional[str] = Form(None),
    file: UploadFile = File(...),
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Upload a video for a specific class and school day. Auto-creates module if needed."""
    if school_day < 1 or school_day > 180:
        raise HTTPException(status_code=400, detail="school_day must be between 1 and 180")

    class_ = db.query(Class).filter(Class.id == class_id).first()
    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    # Find or create a module assigned to this class
    assignment = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.class_id == class_id
    ).first()

    if assignment:
        module_id = str(assignment.module_id)
    else:
        # Auto-create a default module and assign it
        module = LearningModule(
            name=f"Learning Videos",
            description=f"Auto-created for {class_.name}",
            created_by=user.id,
        )
        db.add(module)
        db.flush()
        new_assignment = LearningModuleAssignment(
            module_id=module.id,
            class_id=class_id,
            assigned_by=str(user.id),
        )
        db.add(new_assignment)
        db.flush()
        module_id = str(module.id)

    # Determine academic year start
    ay_start = None
    if academic_year_start_str:
        try:
            ay = datetime.fromisoformat(academic_year_start_str).date()
            if ay.month != 6 or ay.day != 1:
                raise HTTPException(status_code=400, detail="academic_year_start must be June 1 (YYYY-06-01)")
            ay_start = ay
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid academic_year_start format")
    else:
        start_year, _ = get_academic_year_for_date(date.today())
        ay_start = academic_year_start(start_year)

    # Save file
    try:
        saved_path, original_name, size_label, mime = await save_upload_file(file, "uploads/learning-videos/")
        file_size = os.path.getsize(saved_path) if os.path.exists(saved_path) else 0
        if file_size < MIN_VIDEO_BYTES:
            if os.path.exists(saved_path):
                os.remove(saved_path)
            raise HTTPException(status_code=400, detail="Invalid video file. Please upload a real video.")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to save file: {str(e)}")

    video = LearningVideo(
        module_id=module_id,
        title=title,
        subject_name=subject_name.strip() if subject_name else None,
        description=description,
        file_path=saved_path,
        file_name=original_name,
        file_size=file_size,
        duration=None,
        school_day=school_day,
        academic_year_start=ay_start,
    )
    db.add(video)
    db.commit()
    db.refresh(video)

    return {
        "id": str(video.id),
        "module_id": module_id,
        "title": video.title,
        "subject_name": video.subject_name,
        "file_path": video.file_path,
        "school_day": video.school_day,
        "created_at": video.created_at.isoformat() if video.created_at else None,
    }


@router.post("/branch-upload")
async def upload_video_for_branch(
    branch_id: str = Form(...),
    school_day: int = Form(...),
    title: str = Form(...),
    subject_name: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    academic_year_start_str: Optional[str] = Form(None),
    file: UploadFile = File(...),
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Upload a video for ALL classes in a branch for a given school day."""
    from app.models.branch import Branch
    if school_day < 1 or school_day > 180:
        raise HTTPException(status_code=400, detail="school_day must be between 1 and 180")

    classes = db.query(Class).filter(Class.branch_id == branch_id).all()
    if not classes:
        raise HTTPException(status_code=404, detail="No classes found for this branch")

    ay_start = None
    if academic_year_start_str:
        try:
            ay = datetime.fromisoformat(academic_year_start_str).date()
            if ay.month != 6 or ay.day != 1:
                raise HTTPException(status_code=400, detail="academic_year_start must be June 1")
            ay_start = ay
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid academic_year_start format")
    else:
        start_year, _ = get_academic_year_for_date(date.today())
        ay_start = academic_year_start(start_year)

    try:
        saved_path, original_name, size_label, mime = await save_upload_file(file, "uploads/learning-videos/")
        file_size = os.path.getsize(saved_path) if os.path.exists(saved_path) else 0
        if file_size < MIN_VIDEO_BYTES:
            if os.path.exists(saved_path):
                os.remove(saved_path)
            raise HTTPException(status_code=400, detail="Invalid video file. Please upload a real video.")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to save file: {str(e)}")

    clean_subject = subject_name.strip() if subject_name else None
    uploaded_to = []
    for cls in classes:
        class_id_str = str(cls.id)
        assignment = db.query(LearningModuleAssignment).filter(
            LearningModuleAssignment.class_id == class_id_str
        ).first()
        if assignment:
            module_id = str(assignment.module_id)
        else:
            module = LearningModule(
                name="Learning Videos",
                description=f"Auto-created for {cls.name}",
                created_by=user.id,
            )
            db.add(module)
            db.flush()
            new_assignment = LearningModuleAssignment(
                module_id=module.id,
                class_id=class_id_str,
                assigned_by=str(user.id),
            )
            db.add(new_assignment)
            db.flush()
            module_id = str(module.id)

        video = LearningVideo(
            module_id=module_id,
            title=title,
            subject_name=clean_subject,
            description=description,
            file_path=saved_path,
            file_name=original_name,
            file_size=file_size,
            duration=None,
            school_day=school_day,
            academic_year_start=ay_start,
        )
        db.add(video)
        uploaded_to.append(class_id_str)

    db.commit()
    return {"uploaded_to": len(uploaded_to), "class_ids": uploaded_to}


@router.get("/{module_id}/calendar")
def get_module_calendar(
    module_id: UUID,
    class_id: UUID = Query(...),
    academic_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get Day 1-180 mapping and any videos for each day for a given class."""
    # Authorization: reuse class visibility rules similar to syllabus
    # Verify class exists
    class_ = db.query(Class).filter(Class.id == class_id).first()
    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")

    # Basic permission: admins and coordinators allowed; teachers/parents restricted to their classes
    if current_user.role not in ("admin", "coordinator"):
        if current_user.role == "teacher":
            assignments = db.query(BranchAssignment).filter(
                BranchAssignment.user_id == current_user.id,
                BranchAssignment.class_id.isnot(None)
            ).all()
            user_class_ids = [a.class_id for a in assignments]
            if class_id not in user_class_ids:
                raise HTTPException(status_code=403, detail="You don't have permission to view this class")
        elif current_user.role == "parent":
            from app.models.student import Student, ParentStudentLink
            links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == current_user.id).all()
            student_ids = [l.student_id for l in links]
            children = db.query(Student).filter(Student.id.in_(student_ids)).all() if student_ids else []
            children_class_ids = [c.class_id for c in children if c.class_id]
            if class_id not in children_class_ids:
                raise HTTPException(status_code=403, detail="You don't have permission to view this class")
        else:
            raise HTTPException(status_code=403, detail="You don't have permission to view this class")

    start_year = academic_year if academic_year else get_academic_year_for_date(date.today())[0]
    ay_start = academic_year_start(start_year)
    # Get holiday dates for class' branch (include global holidays)
    rows = db.query(SyllabusHoliday).filter(
        SyllabusHoliday.academic_year_start == ay_start,
        (SyllabusHoliday.branch_id.is_(None)) | (SyllabusHoliday.branch_id == class_.branch_id),
    ).all()
    holiday_dates = {r.holiday_date for r in rows}

    days_data = get_school_days_with_dates(start_year, holiday_dates)

    # Collect videos for this module that have school_day and matching academic_year_start
    videos_query = db.query(LearningVideo).filter(
        LearningVideo.module_id == str(module_id),
        LearningVideo.school_day.isnot(None),
        LearningVideo.academic_year_start == ay_start,
    )
    videos_by_day = {}
    for v in videos_query.all():
        d = v.school_day
        if d not in videos_by_day:
            videos_by_day[d] = []
        videos_by_day[d].append({
            "id": str(v.id),
            "title": v.title,
            "file_name": v.file_name,
            "file_path": v.file_path,
            "uploader": None,
        })

    result_days = [
        {"day": item["day"], "date": item["date"], "videos": videos_by_day.get(item["day"], [])}
        for item in days_data
    ]

    return {
        "academic_year_start": ay_start.isoformat(),
        "academic_year_str": f"{start_year}-{str(start_year+1)[2:]}",
        "days": result_days,
    }


@router.post("/{module_id}/assign-to-class/{class_id}")
def assign_module_to_class(
    module_id: str,
    class_id: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Assign a learning module to a class (admin only)."""
    # Check module exists
    module = db.query(LearningModule).filter(LearningModule.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")
    
    # Check if already assigned to this class
    existing = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.module_id == module_id,
        LearningModuleAssignment.class_id == class_id,
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Module already assigned to this class")
    
    # Create assignment
    assignment = LearningModuleAssignment(
        module_id=module_id,
        class_id=class_id,
        assigned_by=str(user.id),
    )
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    
    return {
        "id": str(assignment.id),
        "module_id": str(assignment.module_id),
        "class_id": assignment.class_id,
        "assigned_at": assignment.assigned_at.isoformat() if assignment.assigned_at else None,
    }


@router.post("/{module_id}/assign-to-branch/{branch_id}")
def assign_module_to_branch(
    module_id: str,
    branch_id: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Assign a learning module to a branch (admin only)."""
    # Check module exists
    module = db.query(LearningModule).filter(LearningModule.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")
    
    # Check if already assigned to this branch
    existing = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.module_id == module_id,
        LearningModuleAssignment.branch_id == branch_id,
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Module already assigned to this branch")
    
    # Create assignment
    assignment = LearningModuleAssignment(
        module_id=module_id,
        branch_id=branch_id,
        assigned_by=str(user.id),
    )
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    
    return {
        "id": str(assignment.id),
        "module_id": str(assignment.module_id),
        "branch_id": assignment.branch_id,
        "assigned_at": assignment.assigned_at.isoformat() if assignment.assigned_at else None,
    }


@router.delete("/{module_id}/unassign-from-class/{class_id}")
def unassign_module_from_class(
    module_id: str,
    class_id: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Unassign a learning module from a class (admin only)."""
    assignment = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.module_id == module_id,
        LearningModuleAssignment.class_id == class_id,
    ).first()
    
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    
    db.delete(assignment)
    db.commit()
    
    return {"message": "Module unassigned from class successfully"}


@router.delete("/{module_id}/unassign-from-branch/{branch_id}")
def unassign_module_from_branch(
    module_id: str,
    branch_id: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Unassign a learning module from a branch (admin only)."""
    assignment = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.module_id == module_id,
        LearningModuleAssignment.branch_id == branch_id,
    ).first()
    
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    
    db.delete(assignment)
    db.commit()
    
    return {"message": "Module unassigned from branch successfully"}


@router.delete("/videos/{video_id}")
def delete_video(
    video_id: UUID,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Delete a video from a learning module (admin only)."""
    video = db.query(LearningVideo).filter(LearningVideo.id == str(video_id)).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    db.delete(video)
    db.commit()

    return {"message": "Video deleted successfully"}
