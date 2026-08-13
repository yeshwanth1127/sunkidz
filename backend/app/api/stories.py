"""Bedtime / daily stories — admin upload, parents watch by branch/class scope."""
import json
import os
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.auth import get_current_user, get_optional_user, require_admin
from app.core.database import get_db
from app.core.security import decode_access_token
from app.models.branch import Branch, Class
from app.models.daily_story import DailyStory, DailyStoryBranch, DailyStoryClass
from app.models.student import Student, ParentStudentLink
from app.models.user import User
from app.schemas.stories import StoryResponse, StoryScopeItem, StoryUpdateRequest
from app.services.media_files import save_story_file, media_kind_for_filename, mime_for_filename

router = APIRouter(prefix="/stories", tags=["stories"])

STORIES_DIR = os.path.join("uploads", "stories")


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


def _parse_uuid_list(raw: Optional[str], field_name: str) -> List[UUID]:
    if not raw or not raw.strip():
        return []
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=400, detail=f"Invalid JSON for {field_name}") from e
    if not isinstance(data, list):
        raise HTTPException(status_code=400, detail=f"{field_name} must be a JSON array")
    out: List[UUID] = []
    for item in data:
        try:
            out.append(UUID(str(item)))
        except ValueError as e:
            raise HTTPException(status_code=400, detail=f"Invalid UUID in {field_name}") from e
    return out


def _story_visible(story: DailyStory, branch_id: Optional[UUID], class_id: Optional[UUID]) -> bool:
    branch_ids = [b.branch_id for b in story.branches]
    class_ids = [c.class_id for c in story.classes]

    if branch_ids:
        if not branch_id or branch_id not in branch_ids:
            return False
    if class_ids:
        if not class_id or class_id not in class_ids:
            return False
    return True


def _serialize_story(db: Session, story: DailyStory) -> StoryResponse:
    branch_rows = story.branches or []
    class_rows = story.classes or []
    branches: List[StoryScopeItem] = []
    classes: List[StoryScopeItem] = []

    for sb in branch_rows:
        b = db.query(Branch).filter(Branch.id == sb.branch_id).first()
        if b:
            branches.append(StoryScopeItem(id=b.id, name=b.name))

    for sc in class_rows:
        c = db.query(Class).filter(Class.id == sc.class_id).first()
        if c:
            classes.append(StoryScopeItem(id=c.id, name=c.name))

    return StoryResponse(
        id=story.id,
        title=story.title,
        description=story.description,
        story_type=story.story_type,
        media_kind=story.media_kind,
        file_name=story.file_name,
        is_active=story.is_active,
        branches=branches,
        classes=classes,
        all_branches=len(branch_rows) == 0,
        all_classes=len(class_rows) == 0,
        created_at=story.created_at.isoformat() if story.created_at else None,
    )


def _set_story_scope(
    db: Session,
    story: DailyStory,
    branch_ids: List[UUID],
    class_ids: List[UUID],
) -> None:
    for sb in list(story.branches):
        db.delete(sb)
    for sc in list(story.classes):
        db.delete(sc)

    for bid in branch_ids:
        if not db.query(Branch).filter(Branch.id == bid).first():
            raise HTTPException(status_code=400, detail=f"Branch {bid} not found")
        db.add(DailyStoryBranch(story_id=story.id, branch_id=bid))

    for cid in class_ids:
        cls = db.query(Class).filter(Class.id == cid).first()
        if not cls:
            raise HTTPException(status_code=400, detail=f"Class {cid} not found")
        if branch_ids and cls.branch_id not in branch_ids:
            raise HTTPException(
                status_code=400,
                detail=f"Class {cls.name} is not in the selected branches",
            )
        db.add(DailyStoryClass(story_id=story.id, class_id=cid))


def _parent_child_pairs(db: Session, user: User, student_id: Optional[UUID]) -> List[tuple]:
    links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == user.id).all()
    if not links:
        return []
    student_ids = [l.student_id for l in links]
    if student_id is not None:
        if student_id not in student_ids:
            return []
        student_ids = [student_id]
    children = db.query(Student).filter(Student.id.in_(student_ids)).all()
    return [(c.branch_id, c.class_id) for c in children]


@router.post("/upload", response_model=StoryResponse)
async def upload_story(
    title: str = Form(...),
    story_type: str = Form("daily"),
    description: Optional[str] = Form(None),
    branch_ids: Optional[str] = Form("[]"),
    class_ids: Optional[str] = Form("[]"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    """Upload a bedtime or daily story (admin). Scope via branch_ids / class_ids JSON arrays; empty = all."""
    title = title.strip()
    if not title:
        raise HTTPException(status_code=400, detail="Title is required")
    if story_type not in ("daily", "bedtime"):
        raise HTTPException(status_code=400, detail="story_type must be daily or bedtime")

    bids = _parse_uuid_list(branch_ids, "branch_ids")
    cids = _parse_uuid_list(class_ids, "class_ids")

    path, orig_name, _size, mime = await save_story_file(file, STORIES_DIR)
    kind = media_kind_for_filename(orig_name)
    if kind not in ("image", "video"):
        if os.path.exists(path):
            os.remove(path)
        raise HTTPException(status_code=400, detail="Stories must be an image or video file")

    story = DailyStory(
        title=title,
        description=description,
        story_type=story_type,
        media_kind=kind,
        file_path=path,
        file_name=orig_name,
        file_mime=mime,
        created_by=admin.id,
    )
    db.add(story)
    db.flush()
    _set_story_scope(db, story, bids, cids)
    db.commit()
    db.refresh(story)
    return _serialize_story(db, story)


@router.get("", response_model=List[StoryResponse])
def list_stories(
    story_type: Optional[str] = Query(None),
    student_id: Optional[UUID] = Query(None),
    include_inactive: bool = Query(False),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """List stories. Parents see only active stories for their child's branch/class."""
    q = db.query(DailyStory)
    if story_type:
        if story_type not in ("daily", "bedtime"):
            raise HTTPException(status_code=400, detail="Invalid story_type")
        q = q.filter(DailyStory.story_type == story_type)

    if user.role == "admin":
        if not include_inactive:
            q = q.filter(DailyStory.is_active.is_(True))
    else:
        q = q.filter(DailyStory.is_active.is_(True))
        if user.role == "parent":
            pairs = _parent_child_pairs(db, user, student_id)
            if not pairs:
                return []
            stories = q.order_by(DailyStory.created_at.desc()).all()
            visible = []
            for s in stories:
                for branch_id, class_id in pairs:
                    if _story_visible(s, branch_id, class_id):
                        visible.append(s)
                        break
            return [_serialize_story(db, s) for s in visible]
        else:
            return []

    stories = q.order_by(DailyStory.created_at.desc()).all()
    return [_serialize_story(db, s) for s in stories]


@router.get("/{story_id}", response_model=StoryResponse)
def get_story(
    story_id: UUID,
    student_id: Optional[UUID] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    story = db.query(DailyStory).filter(DailyStory.id == story_id).first()
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    if user.role == "parent":
        if not story.is_active:
            raise HTTPException(status_code=404, detail="Story not found")
        pairs = _parent_child_pairs(db, user, student_id)
        if not any(_story_visible(story, b, c) for b, c in pairs):
            raise HTTPException(status_code=403, detail="Story not available for your child")
    elif user.role != "admin" and not story.is_active:
        raise HTTPException(status_code=404, detail="Story not found")
    return _serialize_story(db, story)


@router.get("/{story_id}/file")
def story_file(
    story_id: UUID,
    token: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    user = _resolve_request_user(db, current_user, token)
    story = db.query(DailyStory).filter(DailyStory.id == story_id).first()
    if not story or not story.is_active:
        raise HTTPException(status_code=404, detail="Story not found")
    if user.role == "parent":
        pairs = _parent_child_pairs(db, user, None)
        if not any(_story_visible(story, b, c) for b, c in pairs):
            raise HTTPException(status_code=403, detail="Not allowed")
    elif user.role != "admin":
        raise HTTPException(status_code=403, detail="Not allowed")
    if not os.path.exists(story.file_path):
        raise HTTPException(status_code=404, detail="File not found")
    media = story.file_mime or mime_for_filename(story.file_name)
    return FileResponse(path=story.file_path, filename=story.file_name, media_type=media)


@router.patch("/{story_id}", response_model=StoryResponse)
def update_story(
    story_id: UUID,
    data: StoryUpdateRequest,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    story = db.query(DailyStory).filter(DailyStory.id == story_id).first()
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    if data.title is not None:
        t = data.title.strip()
        if not t:
            raise HTTPException(status_code=400, detail="Title cannot be empty")
        story.title = t
    if data.description is not None:
        story.description = data.description
    if data.story_type is not None:
        if data.story_type not in ("daily", "bedtime"):
            raise HTTPException(status_code=400, detail="Invalid story_type")
        story.story_type = data.story_type
    if data.is_active is not None:
        story.is_active = data.is_active
    if data.branch_ids is not None or data.class_ids is not None:
        bids = data.branch_ids if data.branch_ids is not None else [b.branch_id for b in story.branches]
        cids = data.class_ids if data.class_ids is not None else [c.class_id for c in story.classes]
        _set_story_scope(db, story, bids, cids)
    db.commit()
    db.refresh(story)
    return _serialize_story(db, story)


@router.delete("/{story_id}")
def delete_story(
    story_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    story = db.query(DailyStory).filter(DailyStory.id == story_id).first()
    if not story:
        raise HTTPException(status_code=404, detail="Story not found")
    if os.path.exists(story.file_path):
        os.remove(story.file_path)
    db.delete(story)
    db.commit()
    return {"message": "Story deleted"}
