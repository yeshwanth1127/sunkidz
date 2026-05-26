import os
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.core.auth import require_admin
from app.models import User, LearningModule, LearningVideo, LearningModuleAssignment
from app.models import Student
from app.services.media_files import save_upload_file

router = APIRouter(prefix="/learning-modules", tags=["learning-modules"])


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
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to save file: {str(e)}")

    # Create database record
    video = LearningVideo(
        module_id=module.id,
        title=title,
        description=description,
        file_path=saved_path,
        file_name=original_name,
        file_size=file_size,
        duration=None,
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
    """List learning modules assigned to a specific student."""
    # Verify student exists
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Get assigned modules
    assignments = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.student_id == student_id
    ).all()
    
    modules = [db.query(LearningModule).filter(LearningModule.id == str(a.module_id)).first() for a in assignments]
    modules = [m for m in modules if m]  # Filter out None values
    
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


@router.post("/{module_id}/assign-to-student/{student_id}")
def assign_module_to_student(
    module_id: str,
    student_id: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Assign a learning module to a student (admin only)."""
    # Check module exists
    module = db.query(LearningModule).filter(LearningModule.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")
    
    # Check student exists
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    
    # Check if already assigned
    existing = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.module_id == module_id,
        LearningModuleAssignment.student_id == student_id,
    ).first()
    
    if existing:
        raise HTTPException(status_code=400, detail="Module already assigned to this student")
    
    # Create assignment
    assignment = LearningModuleAssignment(
        module_id=module_id,
        student_id=student_id,
        assigned_by=user.id,
    )
    db.add(assignment)
    db.commit()
    db.refresh(assignment)
    
    return {
        "id": str(assignment.id),
        "module_id": str(assignment.module_id),
        "student_id": str(assignment.student_id),
        "assigned_at": assignment.assigned_at.isoformat() if assignment.assigned_at else None,
    }


@router.delete("/{module_id}/unassign-from-student/{student_id}")
def unassign_module_from_student(
    module_id: str,
    student_id: str,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Unassign a learning module from a student (admin only)."""
    assignment = db.query(LearningModuleAssignment).filter(
        LearningModuleAssignment.module_id == module_id,
        LearningModuleAssignment.student_id == student_id,
    ).first()
    
    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")
    
    db.delete(assignment)
    db.commit()
    
    return {"message": "Module unassigned from student successfully"}


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
