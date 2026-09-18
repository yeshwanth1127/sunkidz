from pydantic import BaseModel


class LoginRequest(BaseModel):
    email: str | None = None
    password: str | None = None
    admission_number: str | None = None
    date_of_birth: str | None = None  # YYYY-MM-DD for parent login


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    role: str
    branch_id: str | None = None
    class_id: str | None = None
    student_ids: list[str] | None = None  # For parent: list of student IDs they can access
