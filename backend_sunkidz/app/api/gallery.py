"""Branch Gallery module.

- Admins, coordinators and teachers upload/edit/delete photos & videos, scoped
  to the branches they are assigned to (admins: every branch).
- Parents get read-only access to the whole gallery feed -- they can view every
  uploaded photo/video but never upload or manage.
- Every other role has no access.

Auth/permission model follows the rest of the app:
- `get_current_user` / `get_optional_user` for authentication
- role + branch-assignment checks via `app.services.class_access`
- file handling via `app.services.media_files` (same validation used by
  stories: allowed image/video extensions, size cap, video signature check)

Endpoints live under `/gallery/*` but deliberately avoid the exact paths
already taken by the class-scoped gallery in `app/api/syllabus.py`
(`GET /gallery`, `POST /gallery/upload`, `GET /gallery/{id}/file`).
"""
import os
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.auth import get_current_user, get_optional_user
from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.branch import Branch
from app.models.gallery import GalleryItem
from app.models.user import User
from app.schemas.gallery import (
    GalleryBranchOption,
    GalleryItemResponse,
    GalleryItemUpdate,
)
from app.services.class_access import (
    can_manage_branch_gallery,
    get_user_branch_ids,
)
from app.services.media_files import media_kind_for_filename, mime_for_filename, save_story_file

router = APIRouter(prefix="/gallery", tags=["gallery"])

GALLERY_ITEMS_DIR = os.path.join("uploads", "gallery_items")
os.makedirs(GALLERY_ITEMS_DIR, exist_ok=True)

UPLOAD_ROLES = ("admin", "coordinator", "teacher")


def _resolve_request_user(
    db: Session, current_user: Optional[User], token: Optional[str]
) -> User:
    """Same fallback the stories/syllabus file endpoints use: allow the JWT
    to arrive as a query param so an <img>/<video> tag can load the file."""
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


def _require_upload_role(user: User) -> None:
    if user.role not in UPLOAD_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins, coordinators and teachers can manage gallery content",
        )


def _visible_branch_ids(db: Session, user: User) -> Optional[List[UUID]]:
    """Branches whose gallery items ``user`` may view.

    ``None`` means "every branch". Staff are limited to the branches they are
    assigned to (admins get ``None``); parents can view the whole gallery;
    anyone else gets ``[]`` (no access).
    """
    if user.role in UPLOAD_ROLES:
        return get_user_branch_ids(db, user)
    if user.role == "parent":
        return None
    return []


def _serialize(db: Session, item: GalleryItem, user: User) -> GalleryItemResponse:
    branch = db.query(Branch).filter(Branch.id == item.branch_id).first()
    uploader = (
        db.query(User).filter(User.id == item.uploaded_by).first()
        if item.uploaded_by
        else None
    )
    return GalleryItemResponse(
        id=item.id,
        branch_id=item.branch_id,
        branch_name=branch.name if branch else None,
        media_type=item.media_type,
        title=item.title,
        description=item.description,
        file_name=item.file_name,
        file_size=item.file_size,
        uploaded_by=item.uploaded_by,
        uploader_name=uploader.full_name if uploader else None,
        can_manage=can_manage_branch_gallery(db, user, item.branch_id),
        created_at=item.created_at.isoformat() if item.created_at else None,
        updated_at=item.updated_at.isoformat() if item.updated_at else None,
    )


@router.get("/branch-options", response_model=List[GalleryBranchOption])
def list_branch_options(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Branches the current user may filter by / upload to.

    Staff get the branches they are assigned to; parents get every branch so
    their view-only feed can be filtered.
    """
    branch_ids = _visible_branch_ids(db, user)
    q = db.query(Branch)
    if branch_ids is not None:
        if not branch_ids:
            return []
        q = q.filter(Branch.id.in_(branch_ids))
    branches = q.order_by(Branch.name.asc()).all()
    return [GalleryBranchOption(id=b.id, name=b.name) for b in branches]


@router.get("/items", response_model=List[GalleryItemResponse])
def list_items(
    branch_id: Optional[UUID] = Query(None),
    media_type: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """List gallery items visible to the current user.

    Staff see their assigned branches; parents see every uploaded item.
    """
    if media_type is not None and media_type not in ("image", "video"):
        raise HTTPException(status_code=400, detail="media_type must be image or video")

    branch_ids = _visible_branch_ids(db, user)
    q = db.query(GalleryItem)
    if branch_ids is not None:
        if not branch_ids:
            return []
        q = q.filter(GalleryItem.branch_id.in_(branch_ids))
    if branch_id is not None:
        if branch_ids is not None and branch_id not in branch_ids:
            raise HTTPException(status_code=403, detail="You don't have access to this branch")
        q = q.filter(GalleryItem.branch_id == branch_id)
    if media_type is not None:
        q = q.filter(GalleryItem.media_type == media_type)

    items = q.order_by(GalleryItem.created_at.desc()).all()
    return [_serialize(db, item, user) for item in items]


@router.post("/items", response_model=GalleryItemResponse)
async def upload_item(
    branch_id: UUID = Form(...),
    title: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Upload a photo or video to a branch gallery (admin/coordinator/teacher)."""
    _require_upload_role(user)

    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    if not can_manage_branch_gallery(db, user, branch_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to upload to this branch",
        )

    # save_story_file validates extension (image/video only), size cap and
    # video container signature, and stores the file under a uuid name.
    path, orig_name, size_label, mime = await save_story_file(file, GALLERY_ITEMS_DIR)
    media_type = media_kind_for_filename(orig_name)
    if media_type not in ("image", "video"):
        if os.path.exists(path):
            os.remove(path)
        raise HTTPException(status_code=400, detail="Gallery items must be an image or video file")

    clean_title = (title or "").strip() or None
    clean_desc = (description or "").strip() or None

    item = GalleryItem(
        branch_id=branch_id,
        uploaded_by=user.id,
        media_type=media_type,
        title=clean_title,
        description=clean_desc,
        file_path=path,
        file_name=orig_name,
        file_mime=mime,
        file_size=size_label,
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return _serialize(db, item, user)


@router.patch("/items/{item_id}", response_model=GalleryItemResponse)
def update_item(
    item_id: UUID,
    data: GalleryItemUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Update a gallery item's title/description (admin/coordinator/teacher
    with access to the item's branch)."""
    _require_upload_role(user)
    item = db.query(GalleryItem).filter(GalleryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Gallery item not found")
    if not can_manage_branch_gallery(db, user, item.branch_id):
        raise HTTPException(status_code=403, detail="You don't have permission to manage this item")

    if data.title is not None:
        item.title = data.title.strip() or None
    if data.description is not None:
        item.description = data.description.strip() or None
    db.commit()
    db.refresh(item)
    return _serialize(db, item, user)


@router.delete("/items/{item_id}")
def delete_item(
    item_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Delete a gallery item and its stored file (admin/coordinator/teacher
    with access to the item's branch)."""
    _require_upload_role(user)
    item = db.query(GalleryItem).filter(GalleryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Gallery item not found")
    if not can_manage_branch_gallery(db, user, item.branch_id):
        raise HTTPException(status_code=403, detail="You don't have permission to delete this item")

    if item.file_path and os.path.exists(item.file_path):
        try:
            os.remove(item.file_path)
        except OSError:
            pass
    db.delete(item)
    db.commit()
    return {"message": "Gallery item deleted"}


@router.get("/items/{item_id}/file")
def get_item_file(
    item_id: UUID,
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Stream a gallery item's file to any user who can see its branch."""
    user = _resolve_request_user(db, current_user, token)
    item = db.query(GalleryItem).filter(GalleryItem.id == item_id).first()
    if not item:
        raise HTTPException(status_code=404, detail="Gallery item not found")

    branch_ids = _visible_branch_ids(db, user)
    if branch_ids is not None and item.branch_id not in branch_ids:
        raise HTTPException(status_code=403, detail="You don't have access to this item")

    if not os.path.exists(item.file_path):
        raise HTTPException(status_code=404, detail="File not found")
    media = item.file_mime or mime_for_filename(item.file_name)
    return FileResponse(path=item.file_path, filename=item.file_name, media_type=media)
