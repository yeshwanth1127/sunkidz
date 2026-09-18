"""Add any missing canonical classes (Playgroup, IG1, IG2, IG3) per branch.

Pure top-up, no renames: for every branch, insert whichever of the 4
canonical classes it doesn't already have (matched case-insensitively
against Playgroup/Playschool/IG1/IG2/IG3/legacy spellings so an existing
row is never duplicated). No existing class row's name, id, or data is
touched -- this is strictly additive.

Concretely, this fixes Munekolala (branch_id
fbf10ad7-4d38-48da-9dd2-1eacb56db1fd), which has IG1/IG2/IG3 but was never
given a Playgroup-equivalent class, unlike Aecs Layout and Ashwath Nagar
which both already have one (spelled "Playschool", left as-is here).
"""
import re
import uuid
from alembic import op
from sqlalchemy import text

revision = "030_add_missing_playgroup_classes"
down_revision = "029_unify_grade_names_no_legacy"
branch_labels = None
depends_on = None

STANDARD_CLASSES = ("Playgroup", "IG1", "IG2", "IG3")

CANONICAL = {
    "playgroup": "Playgroup",
    "playschool": "Playgroup",
    "nursery": "Playgroup",
    "ig1": "IG1", "1g1": "IG1", "ig-1": "IG1", "lkg": "IG1",
    "ig2": "IG2", "1g2": "IG2", "ig-2": "IG2", "ukg": "IG2",
    "ig3": "IG3", "1g3": "IG3", "ig-3": "IG3",
}


def canonical(name: str) -> str:
    key = re.sub(r"[\s\-]+", "", name).lower()
    return CANONICAL.get(key, name.strip())


def upgrade() -> None:
    conn = op.get_bind()
    branches = conn.execute(text("SELECT id FROM branches")).fetchall()
    for branch in branches:
        branch_id = str(branch.id)
        existing_canonical = {
            canonical(r.name)
            for r in conn.execute(
                text("SELECT name FROM classes WHERE branch_id = :bid"),
                {"bid": branch_id},
            ).fetchall()
        }
        for name in STANDARD_CLASSES:
            if name not in existing_canonical:
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
    # Additive-only migration -- no safe way to distinguish inserted rows
    # from pre-existing ones after the fact, so this is one-way.
    pass
