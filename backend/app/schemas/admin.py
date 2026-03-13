from pydantic import BaseModel
from uuid import UUID


class BranchCreate(BaseModel):
    name: str
    code: str | None = None  # e.g. acs, mun, ash for admission numbers
    address: str | None = None
    contact_no: str | None = None
    status: str = "active"


class BranchUpdate(BaseModel):
    name: str | None = None
    code: str | None = None
    address: str | None = None
    contact_no: str | None = None
    status: str | None = None


class ClassCreate(BaseModel):
    branch_id: UUID
    name: str
    academic_year: str | None = "2024-25"


class ClassUpdate(BaseModel):
    name: str | None = None
    academic_year: str | None = None


class UserCreate(BaseModel):
    email: str | None = None
    password: str | None = None  # Optional for toddlers/daycare (they use email+DOB)
    full_name: str
    role: str  # teacher, coordinator, bus_staff, toddlers, daycare
    phone: str | None = None
    date_of_birth: str | None = None  # YYYY-MM-DD for toddlers/daycare


class UserUpdate(BaseModel):
    email: str | None = None
    full_name: str | None = None
    phone: str | None = None
    is_active: str | None = None


class AssignmentCreate(BaseModel):
    user_id: UUID
    branch_id: UUID
    class_id: UUID | None = None  # None for coordinators


class AssignmentUpdate(BaseModel):
    branch_id: UUID | None = None
    class_id: UUID | None = None


# Response schemas
class ClassResponse(BaseModel):
    id: str
    branch_id: str
    name: str
    academic_year: str | None

    class Config:
        from_attributes = True


class BranchResponse(BaseModel):
    id: str
    name: str
    address: str | None
    contact_no: str | None
    status: str
    classes: list[ClassResponse] = []
    coordinator_name: str | None = None
    student_count: int = 0

    class Config:
        from_attributes = True


class UserResponse(BaseModel):
    id: str
    email: str | None
    full_name: str
    role: str
    phone: str | None
    date_of_birth: str | None = None
    is_active: str
    branch_id: str | None = None
    branch_name: str | None = None
    class_id: str | None = None
    class_name: str | None = None

    class Config:
        from_attributes = True


class AssignmentResponse(BaseModel):
    id: str
    user_id: str
    user_name: str
    user_role: str
    branch_id: str
    branch_name: str
    class_id: str | None
    class_name: str | None

    class Config:
        from_attributes = True
