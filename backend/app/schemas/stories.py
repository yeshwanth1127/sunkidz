from typing import List, Optional
from uuid import UUID
from pydantic import BaseModel, Field


class StoryScopeItem(BaseModel):
    id: UUID
    name: str


class StoryResponse(BaseModel):
    id: UUID
    title: str
    description: Optional[str] = None
    story_type: str
    media_kind: str
    file_name: str
    is_active: bool
    branches: List[StoryScopeItem] = Field(default_factory=list)
    classes: List[StoryScopeItem] = Field(default_factory=list)
    all_branches: bool = False
    all_classes: bool = False
    created_at: Optional[str] = None

    class Config:
        from_attributes = True


class StoryUpdateRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    story_type: Optional[str] = None
    is_active: Optional[bool] = None
    branch_ids: Optional[List[UUID]] = None
    class_ids: Optional[List[UUID]] = None
