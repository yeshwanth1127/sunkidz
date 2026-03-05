from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.auth import get_current_user
from app.models.user import User
from app.models.branch import BranchAssignment
from app.schemas.user import UserResponse

router = APIRouter(prefix="/auth", tags=["auth"])


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
        branch_id=branch_id,
        class_id=class_id,
    )
