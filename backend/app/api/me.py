from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.auth import get_current_user
from app.core.security import verify_password, get_password_hash
from app.models.user import User
from app.models.branch import BranchAssignment
from app.schemas.user import UserResponse, PasswordChangeRequest, UserProfileUpdateRequest
import os
import uuid
from datetime import date

router = APIRouter(prefix="/auth", tags=["auth"])

# Directory for profile photos
UPLOAD_DIR = "uploads"
PROFILE_PHOTO_DIR = os.path.join(UPLOAD_DIR, "profile_photos")
os.makedirs(PROFILE_PHOTO_DIR, exist_ok=True)


@router.get("/me", response_model=UserResponse)
def get_me(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    branch_id = None
    class_id = None
    assignment = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    if assignment:
        branch_id = str(assignment.branch_id)
        class_id = str(assignment.class_id) if assignment.class_id else None
    return UserResponse(
        id=str(user.id),
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        phone=user.phone,
        date_of_birth=user.date_of_birth.isoformat() if user.date_of_birth else None,
        branch_id=branch_id,
        class_id=class_id,
        profile_photo=user.profile_photo,
    )


@router.put("/me", response_model=UserResponse)
def update_me(
    data: UserProfileUpdateRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if data.full_name is not None:
        full_name = data.full_name.strip()
        if not full_name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Full name cannot be empty",
            )
        user.full_name = full_name

    if data.phone is not None:
        phone = data.phone.strip()
        user.phone = phone or None

    if data.email is not None:
        email = data.email.strip().lower()
        if email:
            existing = db.query(User).filter(User.email == email, User.id != user.id).first()
            if existing:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email already in use",
                )
            user.email = email
        else:
            user.email = None

    if data.date_of_birth is not None:
        dob_text = data.date_of_birth.strip()
        if not dob_text:
            user.date_of_birth = None
        else:
            try:
                user.date_of_birth = date.fromisoformat(dob_text)
            except ValueError:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid date format. Use YYYY-MM-DD",
                )

    db.commit()
    db.refresh(user)

    branch_id = None
    class_id = None
    assignment = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    if assignment:
        branch_id = str(assignment.branch_id)
        class_id = str(assignment.class_id) if assignment.class_id else None
    return UserResponse(
        id=str(user.id),
        email=user.email,
        full_name=user.full_name,
        role=user.role,
        phone=user.phone,
        date_of_birth=user.date_of_birth.isoformat() if user.date_of_birth else None,
        branch_id=branch_id,
        class_id=class_id,
        profile_photo=user.profile_photo,
    )


@router.post("/upload-profile-photo")
async def upload_profile_photo(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Upload profile photo."""
    # Validate file type
    allowed_extensions = {".jpg", ".jpeg", ".png", ".gif"}
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid file type. Only JPG, PNG, and GIF are allowed."
        )
    
    # Delete old photo if exists
    if user.profile_photo and os.path.exists(user.profile_photo):
        try:
            os.remove(user.profile_photo)
        except:
            pass
    
    # Save new photo
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = os.path.join(PROFILE_PHOTO_DIR, unique_filename)
    
    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)
    
    # Update user record
    user.profile_photo = file_path
    db.commit()
    
    return {"message": "Profile photo uploaded successfully", "file_path": file_path}


@router.delete("/delete-profile-photo")
def delete_profile_photo(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Delete profile photo."""
    if not user.profile_photo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No profile photo to delete"
        )
    
    # Delete file
    if os.path.exists(user.profile_photo):
        try:
            os.remove(user.profile_photo)
        except:
            pass
    
    # Update user record
    user.profile_photo = None
    db.commit()
    
    return {"message": "Profile photo deleted successfully"}


@router.get("/profile-photo/{user_id}")
def get_profile_photo(
    user_id: str,
    db: Session = Depends(get_db),
):
    """Get user's profile photo."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.profile_photo:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile photo not found"
        )
    
    if not os.path.exists(user.profile_photo):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Profile photo file not found"
        )
    
    return FileResponse(user.profile_photo)


@router.post("/change-password")
def change_password(
    password_data: PasswordChangeRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change user password."""
    # Verify current password
    if not verify_password(password_data.current_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect"
        )
    
    # Hash and update new password
    user.password_hash = get_password_hash(password_data.new_password)
    db.commit()
    
    return {"message": "Password changed successfully"}

