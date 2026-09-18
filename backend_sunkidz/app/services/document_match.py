"""Best-effort duplicate detection for the admission-document ingestion
feature. Used by POST /documents/{id}/apply to stop OCR of a re-scanned or
sibling-similar form from silently creating a second Student or a second
parent User.

Deliberately simple (exact/substring name match + normalized last-10-digit
phone match) — same normalization approach already used ad hoc in
`app/api/admin.py::search_parents`.
"""
from datetime import date as date_type
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.student import Student
from app.models.user import User


def normalize_phone(value: Optional[str]) -> str:
    digits = "".join(ch for ch in (value or "") if ch.isdigit())
    return digits[-10:] if len(digits) >= 10 else digits


def find_candidate_students(
    db: Session,
    *,
    name: Optional[str],
    date_of_birth: Optional[date_type],
    branch_id: Optional[UUID],
) -> list[Student]:
    """Students in the same branch with the same date of birth (a strong
    duplicate signal for preschool-age children) and a name that at least
    overlaps with the OCR'd name."""
    if not date_of_birth or not branch_id:
        return []
    candidates = (
        db.query(Student)
        .filter(Student.branch_id == branch_id, Student.date_of_birth == date_of_birth)
        .all()
    )
    if not name or not candidates:
        return candidates
    name_norm = name.strip().lower()
    if not name_norm:
        return candidates
    narrowed = [
        s
        for s in candidates
        if s.name
        and (
            s.name.strip().lower() == name_norm
            or name_norm in s.name.strip().lower()
            or s.name.strip().lower() in name_norm
        )
    ]
    return narrowed or candidates


def find_candidate_parents(db: Session, *, phone: Optional[str], name: Optional[str]) -> list[User]:
    """Existing parent Users matching by normalized phone or exact name.
    Informational/broad — used to populate the candidate list shown to a
    human when a conflict needs resolving. NOT used to decide whether to
    auto-link without asking; a name-only match is too weak a signal for
    that (see `find_candidate_parents_by_phone`)."""
    phone_norm = normalize_phone(phone)
    name_norm = (name or "").strip().lower()
    if not phone_norm and not name_norm:
        return []
    users = db.query(User).filter(User.role == "parent").all()
    matches = []
    seen = set()
    for u in users:
        hit = (phone_norm and normalize_phone(u.phone) == phone_norm) or (
            name_norm and u.full_name and u.full_name.strip().lower() == name_norm
        )
        if hit and u.id not in seen:
            matches.append(u)
            seen.add(u.id)
    return matches


def find_candidate_parents_by_phone(db: Session, *, phone: Optional[str]) -> list[User]:
    """Existing parent Users matching by normalized phone only. A phone match
    is a strong enough identity signal to auto-link a new student to an
    existing parent (e.g. a sibling) without a human confirming — used by the
    fully-automatic apply path. A single hit here is safe to reuse silently."""
    phone_norm = normalize_phone(phone)
    if not phone_norm:
        return []
    users = db.query(User).filter(User.role == "parent").all()
    return [u for u in users if normalize_phone(u.phone) == phone_norm]
