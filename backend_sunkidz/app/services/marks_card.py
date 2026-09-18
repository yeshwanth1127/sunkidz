"""Single-source-of-truth helpers for a student's Marks Card.

There is exactly **one current Marks Card per (student, academic_year)** — the
DB enforces this with a unique index (see migration 002 / 032). These helpers
keep every read/write pointed at that one latest row and self-heal if a stale
duplicate ever slips in (e.g. a table created by ``Base.metadata.create_all``
before the index existed).
"""
import os
import uuid as _uuid
from datetime import datetime, timezone
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models import MarksCard

_MIN_DT = datetime.min.replace(tzinfo=timezone.utc)

# ── Signature images ──────────────────────────────────────────────────────────
# Stored on the ONE current card's JSONB `data` under `sig_<role>` as a path
# relative to the app root, served by the existing `/uploads` static mount.
SIGNATURE_DIR = os.path.join("uploads", "marks_signatures")
SIGNATURE_ROLES = ("parent", "class_teacher", "principal")
SIGNATURE_EXTS = {".png", ".jpg", ".jpeg"}
MAX_SIGNATURE_BYTES = 6 * 1024 * 1024  # 6 MB — a signature image is tiny
_SIG_KEYS = tuple(f"sig_{r}" for r in SIGNATURE_ROLES)


def signature_key(role: str) -> str:
    if role not in SIGNATURE_ROLES:
        raise HTTPException(
            status_code=400,
            detail=f"role must be one of: {', '.join(SIGNATURE_ROLES)}",
        )
    return f"sig_{role}"


def preserve_signatures(existing: dict | None, incoming: dict | None) -> dict:
    """Carry the signature-image keys from the stored card into a marks-form
    save payload — the marks form never edits signatures, so a save must not
    drop them."""
    existing = existing or {}
    out = dict(incoming or {})
    for k in _SIG_KEYS:
        if k in existing and k not in out:
            out[k] = existing[k]
    return out


def save_marks_signature(
    db: Session,
    student_id: UUID,
    academic_year: str,
    role: str,
    filename: str | None,
    content: bytes,
) -> dict:
    """Persist a PNG/JPG/JPEG signature image for `role` on the student's one
    current marks card, replacing any previous image for that role. Returns the
    stored relative path plus the full updated card `data`."""
    key = signature_key(role)
    ext = os.path.splitext((filename or "").lower())[1]
    if ext not in SIGNATURE_EXTS:
        raise HTTPException(
            status_code=400, detail="Signature must be a PNG, JPG or JPEG image"
        )
    if not content:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(content) > MAX_SIGNATURE_BYTES:
        raise HTTPException(status_code=400, detail="Signature image too large (max 6 MB)")

    card = latest_marks_card_pruning_duplicates(db, student_id, academic_year)
    if card is None:
        raise HTTPException(
            status_code=404, detail="Save the marks card before adding a signature"
        )

    os.makedirs(SIGNATURE_DIR, exist_ok=True)
    unique_name = f"{_uuid.uuid4().hex}{ext}"
    with open(os.path.join(SIGNATURE_DIR, unique_name), "wb") as fh:
        fh.write(content)
    rel_path = f"{SIGNATURE_DIR.replace(os.sep, '/')}/{unique_name}"

    data = dict(card.data or {})
    old_path = data.get(key)
    data[key] = rel_path
    card.data = data  # reassign so SQLAlchemy flags the JSONB column dirty
    db.commit()
    db.refresh(card)

    # best-effort cleanup of the replaced file (basename only — no traversal)
    if isinstance(old_path, str) and old_path:
        try:
            os.remove(os.path.join(SIGNATURE_DIR, os.path.basename(old_path)))
        except OSError:
            pass

    return {"role": role, "key": key, "path": rel_path, "data": card.data}


def _aware(dt: datetime | None) -> datetime:
    if dt is None:
        return _MIN_DT
    return dt if dt.tzinfo is not None else dt.replace(tzinfo=timezone.utc)


def card_recency_key(card) -> tuple:
    """Sort key where the newest ("current") card compares greatest."""
    touched = getattr(card, "updated_at", None) or getattr(card, "created_at", None)
    return (
        _aware(touched),
        _aware(getattr(card, "sent_to_parent_at", None)),
        str(getattr(card, "id", "")),
    )


def marks_cards_ordered(db: Session, student_id: UUID, academic_year: str) -> list:
    """All rows for the pair, newest first (defensive — normally 0 or 1)."""
    return (
        db.query(MarksCard)
        .filter(
            MarksCard.student_id == student_id,
            MarksCard.academic_year == academic_year,
        )
        .order_by(
            func.coalesce(MarksCard.updated_at, MarksCard.created_at).desc(),
            MarksCard.created_at.desc(),
            MarksCard.id.desc(),
        )
        .all()
    )


def latest_marks_card(db: Session, student_id: UUID, academic_year: str):
    """The one current card for the pair, or ``None``."""
    rows = marks_cards_ordered(db, student_id, academic_year)
    return rows[0] if rows else None


def latest_marks_card_pruning_duplicates(
    db: Session, student_id: UUID, academic_year: str
):
    """The current card; any older duplicate rows are deleted (not committed)."""
    rows = marks_cards_ordered(db, student_id, academic_year)
    if not rows:
        return None
    for stale in rows[1:]:
        db.delete(stale)
    return rows[0]
