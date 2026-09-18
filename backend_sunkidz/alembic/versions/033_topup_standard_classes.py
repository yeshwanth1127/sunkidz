"""Re-assert the 4 canonical classes (Playgroup, IG1, IG2, IG3) on every branch

Revision ID: 033_topup_standard_classes
Revises: 032_marks_card_single_current
Create Date: 2026-09-02

Migration 030 already did this once, but on environments where the schema
was created by ``Base.metadata.create_all`` + ``alembic stamp`` (so 030 never
actually ran), branches such as **Munekolala** ended up with only
IG1 / IG2 / IG3 and no Playgroup-level class. Because every grade/class
dropdown in the app (Daily Reports, Marks Card, Attendance, Almanac, Diary,
Syllabus, Homework, Learning Modules, Messages, ...) is populated from the
`classes` table for the branch, the missing row hides Playgroup everywhere
at once.

This migration is a **pure additive top-up**: for every branch, insert
whichever of Playgroup / IG1 / IG2 / IG3 it does not already have (matched
case/space/dash-insensitively against the current + legacy spellings so an
existing row -- e.g. "Playschool" -- is never duplicated). No existing class
row's id, name, or data is touched.
"""
import re
import uuid

from alembic import op
from sqlalchemy import text

revision = "033_topup_standard_classes"
down_revision = "032_marks_card_single_current"
branch_labels = None
depends_on = None

STANDARD_CLASSES = ("Playgroup", "IG1", "IG2", "IG3")

_CANONICAL = {
    "playgroup": "Playgroup",
    "playschool": "Playgroup",
    "nursery": "Playgroup",
    "ig1": "IG1", "1g1": "IG1", "ig-1": "IG1", "lkg": "IG1",
    "ig2": "IG2", "1g2": "IG2", "ig-2": "IG2", "ukg": "IG2",
    "ig3": "IG3", "1g3": "IG3", "ig-3": "IG3",
}


def _canonical(name: str) -> str:
    key = re.sub(r"[\s\-_]+", "", name or "").lower()
    return _CANONICAL.get(key, (name or "").strip())


def upgrade() -> None:
    conn = op.get_bind()
    branches = conn.execute(text("SELECT id FROM branches")).fetchall()
    for branch in branches:
        branch_id = str(branch.id)
        have = {
            _canonical(r.name)
            for r in conn.execute(
                text("SELECT name FROM classes WHERE branch_id = :bid"),
                {"bid": branch_id},
            ).fetchall()
        }
        for name in STANDARD_CLASSES:
            if name not in have:
                conn.execute(
                    text(
                        "INSERT INTO classes (id, branch_id, name, academic_year, created_at) "
                        "VALUES (:id, :branch_id, :name, :academic_year, now())"
                    ),
                    {
                        "id": str(uuid.uuid4()),
                        "branch_id": branch_id,
                        "name": name,
                        "academic_year": "2026-27",
                    },
                )


def downgrade() -> None:
    # Additive-only: there is no safe way to tell inserted rows from
    # pre-existing ones after the fact.
    pass
