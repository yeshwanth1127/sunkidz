from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.core.database import get_db
from app.core.auth import require_admin
from app.models import User, LearningModule, LearningVideo
from app.services.media_files import save_upload_file, validate_upload_file

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
    module = db.query(LearningModule).filter(LearningModule.id == module_id).first()
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
    module = db.query(LearningModule).filter(LearningModule.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")

    # Validate file
    try:
        file_data = await file.read()
        file.file.seek(0)
        file_path, file_size = validate_upload_file(file, file_data, "uploads/learning-videos/")
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Save file
    saved_path = save_upload_file(file_data, file_path, file_size)

    # Create database record
    video = LearningVideo(
        module_id=module.id,
        title=title,
        description=description,
        file_path=saved_path,
        file_name=file.filename,
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
    module = db.query(LearningModule).filter(LearningModule.id == module_id).first()
    if not module:
        raise HTTPException(status_code=404, detail="Module not found")

    db.delete(module)
    db.commit()

    return {"message": "Module deleted successfully"}


@router.delete("/videos/{video_id}")
def delete_video(
    video_id: UUID,
    user: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Delete a video from a learning module (admin only)."""
    video = db.query(LearningVideo).filter(LearningVideo.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Video not found")

    db.delete(video)
    db.commit()

    return {"message": "Video deleted successfully"}
