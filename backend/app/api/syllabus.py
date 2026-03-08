import os
import uuid
from datetime import datetime
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form, Query
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import get_current_user, get_optional_user
from app.core.security import decode_access_token
from app.models.user import User
from app.models.student import Student, ParentStudentLink
from app.models.branch import Class, BranchAssignment
from app.models.syllabus import Syllabus, Homework, GalleryImage
from app.schemas.syllabus import (
    SyllabusResponse,
    SyllabusUpdate,
    HomeworkResponse,
    HomeworkUpdate,
    GalleryResponse,
)

router = APIRouter(tags=["syllabus-homework"])

# Directory for file uploads
UPLOAD_DIR = "uploads"
SYLLABUS_DIR = os.path.join(UPLOAD_DIR, "syllabus")
HOMEWORK_DIR = os.path.join(UPLOAD_DIR, "homework")
GALLERY_DIR = os.path.join(UPLOAD_DIR, "gallery")

# Ensure directories exist
os.makedirs(SYLLABUS_DIR, exist_ok=True)
os.makedirs(HOMEWORK_DIR, exist_ok=True)
os.makedirs(GALLERY_DIR, exist_ok=True)


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
    if user.role in ["admin", "coordinator"]:
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
    # Generate unique filename
    file_ext = os.path.splitext(file.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(directory, unique_filename)
    
    # Save file
    with open(file_path, "wb") as buffer:
        content = await file.read()
        buffer.write(content)
    
    # Get file size
    file_size = f"{len(content) / 1024:.2f} KB"
    
    return file_path, file.filename, file_size


# ========== SYLLABUS ENDPOINTS ==========

@router.post("/syllabus/upload", response_model=SyllabusResponse)
async def upload_syllabus(
    class_id: UUID = Form(...),
    title: str = Form(...),
    upload_date: str = Form(...),
    description: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upload syllabus (admin or teacher for their class)."""
    # Check authorization
    if not _can_upload_to_class(db, current_user, class_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to upload syllabus for this class"
        )
    
    # Verify class exists
    class_ = db.query(Class).filter(Class.id == class_id).first()
    if not class_:
        raise HTTPException(status_code=404, detail="Class not found")
    
    # Save file
    file_path, file_name, file_size = await _save_file(file, SYLLABUS_DIR)
    
    # Create syllabus record
    syllabus = Syllabus(
        class_id=class_id,
        uploaded_by=current_user.id,
        title=title,
        description=description,
        upload_date=datetime.fromisoformat(upload_date).date(),
        file_path=file_path,
        file_name=file_name,
        file_size=file_size,
    )
    
    db.add(syllabus)
    db.commit()
    db.refresh(syllabus)
    
    return SyllabusResponse(
        id=syllabus.id,
        class_id=syllabus.class_id,
        uploaded_by=syllabus.uploaded_by,
        uploader_name=current_user.full_name,
        title=syllabus.title,
        description=syllabus.description,
        upload_date=syllabus.upload_date,
        file_path=syllabus.file_path,
        file_name=syllabus.file_name,
        file_size=syllabus.file_size,
        class_name=class_.name,
        created_at=syllabus.created_at.isoformat() if syllabus.created_at else "",
    )


@router.get("/syllabus", response_model=List[SyllabusResponse])
def list_syllabus(
    class_id: Optional[UUID] = None,
    upload_date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List syllabus (filtered by class and/or date)."""
    query = db.query(Syllabus)
    
    # Filter by class if specified
    if class_id:
        if not _can_view_class(db, current_user, class_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You don't have permission to view this class"
            )
        query = query.filter(Syllabus.class_id == class_id)
    else:
        # If no class specified, filter by user's accessible classes
        if current_user.role == "teacher":
            user_classes = _get_user_classes(db, current_user)
            if user_classes:
                query = query.filter(Syllabus.class_id.in_(user_classes))
            else:
                return []
    
    # For teachers/coordinators, show only admin-uploaded syllabus
    if current_user.role in ["teacher", "coordinator"]:
        admin_ids = db.query(User.id).filter(User.role == "admin").subquery()
        query = query.filter(Syllabus.uploaded_by.in_(admin_ids))

    # Filter by date if specified
    if upload_date:
        query = query.filter(Syllabus.upload_date == datetime.fromisoformat(upload_date).date())

    syllabi = query.order_by(Syllabus.upload_date.desc()).all()
    
    # Build response
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
            file_path=s.file_path,
            file_name=s.file_name,
            file_size=s.file_size,
            class_name=class_.name if class_ else "",
            created_at=s.created_at.isoformat() if s.created_at else "",
        ))
    
    return result


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
    
    # Update fields
    if data.title:
        syllabus.title = data.title
    if data.description is not None:
        syllabus.description = data.description
    if data.upload_date:
        syllabus.upload_date = data.upload_date
    
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
    
    # For coordinators/parents, show only admin-uploaded homework
    if current_user.role in ["coordinator", "parent"]:
        admin_ids = db.query(User.id).filter(User.role == "admin").subquery()
        query = query.filter(Homework.uploaded_by.in_(admin_ids))
    
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
    
    # For coordinators/parents, only allow viewing admin-uploaded homework
    if current_user.role in ["coordinator", "parent"]:
        uploader = db.query(User).filter(User.id == homework.uploaded_by).first()
        if uploader is None or uploader.role != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only view homework uploaded by admin")
    
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

    uploader = db.query(User).filter(User.id == homework.uploaded_by).first()
    if user.role in ["coordinator", "parent"] and (uploader is None or uploader.role != "admin"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="You can only view homework uploaded by admin")

    if not os.path.exists(homework.file_path):
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(path=homework.file_path, filename=homework.file_name, media_type="application/octet-stream")


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
