"""Unify canonical class/grade names to Playgroup, IG1, IG2, IG3 only.

Legacy names (Nursery, LKG, UKG), the retired "Playschool" spelling, and the
old digit-spelled grades (1G1/1G2/1G3) are renamed to their new canonical
form. If renaming a class would collide with a class that already has the
canonical name in the same branch, the two rows are merged: the older row is
kept, every reference to the newer row's id is repointed to the kept row's
id, and the newer row is deleted. Rows that aren't merged keep their
existing id, so no student/admission/attendance/etc. link is ever broken --
only `classes.name` changes, `classes.id` (what every other table's
class_id foreign key points to) is never altered for a survivor row.

After the rename/merge pass, every branch is topped up so it has exactly
one class for each of the 4 canonical names -- any missing one (e.g. a
branch whose Nursery-equivalent class was deleted or never created) is
inserted, never duplicated (checked by name first).

This mirrors the dedup approach already used by
025_normalize_and_deduplicate_classes, extended to the tables added since:
day_folder and daily_report.
"""
import re
import uuid
from alembic import op
from sqlalchemy import text

revision = "029_unify_grade_names_no_legacy"
down_revision = "028_rename_daily_repertory_to_daily_report"
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

# Tables with a real (UUID) foreign key to classes.id.
FK_TABLES = [
    "students",
    "branch_assignments",
    "class_diary_entries",
    "almanac_events",
    "daily_story_classes",
    "gallery_images",
    "homework",
    "syllabus",
]

# Tables that store class_id as a free varchar (no DB-level FK constraint)
# but still logically reference classes.id.
VARCHAR_TABLES = [
    "learning_module_assignment",
    "day_folder",
    "daily_report",
]


def canonical(name: str) -> str:
    key = re.sub(r"[\s\-]+", "", name).lower()
    return CANONICAL.get(key, name.strip())


def upgrade() -> None:
    conn = op.get_bind()

    # --- Pass 1: rename legacy names, merging any resulting duplicates. ---
    rows = conn.execute(text(
        "SELECT id, branch_id, name, created_at FROM classes ORDER BY created_at ASC"
    )).fetchall()

    groups: dict[tuple, list] = {}
    for row in rows:
        key = (str(row.branch_id), canonical(row.name))
        groups.setdefault(key, []).append(row)

    for (branch_id, canon_name), members in groups.items():
        keeper = members[0]
        keeper_id = str(keeper.id)

        if keeper.name != canon_name:
            conn.execute(text(
                "UPDATE classes SET name = :name WHERE id = :id"
            ), {"name": canon_name, "id": keeper_id})

        for dup in members[1:]:
            dup_id = str(dup.id)

            for table in FK_TABLES + VARCHAR_TABLES:
                conn.execute(text(
                    f"UPDATE {table} SET class_id = :keeper WHERE class_id = :dup"
                ), {"keeper": keeper_id, "dup": dup_id})

            conn.execute(text(
                "DELETE FROM classes WHERE id = :dup"
            ), {"dup": dup_id})

    # --- Pass 2: ensure every branch has all 4 canonical classes. ---
    branches = conn.execute(text("SELECT id FROM branches")).fetchall()
    for branch in branches:
        branch_id = str(branch.id)
        existing_names = {
            r.name
            for r in conn.execute(
                text("SELECT name FROM classes WHERE branch_id = :bid"),
                {"bid": branch_id},
            ).fetchall()
        }
        for name in STANDARD_CLASSES:
            if name not in existing_names:
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
    # Legacy names (Nursery/LKG/UKG/Playschool) are not recoverable once
    # renamed or merged into a canonical row, and newly-inserted classes
    # from pass 2 can't be safely distinguished from pre-existing ones --
    # this migration is intentionally one-way, same as
    # 025_normalize_and_deduplicate_classes.
    pass
