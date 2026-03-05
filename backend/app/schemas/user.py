from pydantic import BaseModel
from uuid import UUID


class UserResponse(BaseModel):
    id: str
    email: str | None
    full_name: str
    role: str
    branch_id: str | None = None
    class_id: str | None = None

    class Config:
        from_attributes = True
