from datetime import date
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import verify_password, create_access_token, get_password_hash
from app.models.user import User
from app.models.student import Student
from app.models.branch import BranchAssignment
from app.schemas.auth import LoginRequest, TokenResponse

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    # Parent login: admission_number + date_of_birth
    if request.admission_number and request.date_of_birth:
        student = db.query(Student).filter(
            Student.admission_number == request.admission_number,
        ).first()
        if not student:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid admission number")
        try:
            dob = date.fromisoformat(request.date_of_birth)
        except ValueError:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid date format. Use YYYY-MM-DD")
        if student.date_of_birth != dob:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
        # Find parent user linked to this student
        from app.models.student import ParentStudentLink
        link = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student.id).first()
        if not link:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="No parent account linked")
        user = db.query(User).filter(User.id == link.user_id).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
        student_ids = [str(s.student_id) for s in db.query(ParentStudentLink).filter(ParentStudentLink.user_id == user.id).all()]
        token = create_access_token(data={"sub": str(user.id), "role": user.role})
        return TokenResponse(
            access_token=token,
            user_id=str(user.id),
            role=user.role,
            branch_id=str(student.branch_id) if student.branch_id else None,
            class_id=None,
            student_ids=student_ids,
        )

    # Staff login: email + password
    if not request.email or not request.password:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email and password required")
    user = db.query(User).filter(User.email == request.email).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if not user.password_hash:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if not verify_password(request.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
    if user.is_active != "true":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Account inactive")

    branch_id = None
    class_id = None
    assignment = db.query(BranchAssignment).filter(BranchAssignment.user_id == user.id).first()
    if assignment:
        branch_id = str(assignment.branch_id)
        class_id = str(assignment.class_id) if assignment.class_id else None

    token = create_access_token(data={"sub": str(user.id), "role": user.role})
    return TokenResponse(
        access_token=token,
        user_id=str(user.id),
        role=user.role,
        branch_id=branch_id,
        class_id=class_id,
    )
