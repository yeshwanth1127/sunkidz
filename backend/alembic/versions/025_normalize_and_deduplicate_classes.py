"""Normalize class names and remove duplicates, add unique constraint."""
import re
from alembic import op
import sqlalchemy as sa
from sqlalchemy import text

revision = "025_normalize_and_deduplicate_classes"
down_revision = "023_learning_video_fields"
branch_labels = None
depends_on = None

CANONICAL = {
    'playschool': 'Playschool',
    'playgroup': 'Playschool',
    '1g1': '1G1', 'ig1': '1G1', 'ig-1': '1G1',
    '1g2': '1G2', 'ig2': '1G2', 'ig-2': '1G2',
    '1g3': '1G3', 'ig3': '1G3', 'ig-3': '1G3',
    'nursery': 'Nursery',
    'lkg': 'LKG',
    'ukg': 'UKG',
}


def canonical(name: str) -> str:
    key = re.sub(r'[\s\-]+', '', name).lower()
    return CANONICAL.get(key, name.strip())


def upgrade() -> None:
    conn = op.get_bind()

    # Load all classes ordered by created_at so oldest = keeper
    rows = conn.execute(text(
        "SELECT id, branch_id, name, created_at FROM classes ORDER BY created_at ASC"
    )).fetchall()

    # Group by (branch_id, canonical_name)
    groups: dict[tuple, list] = {}
    for row in rows:
        key = (str(row.branch_id), canonical(row.name))
        groups.setdefault(key, []).append(row)

    for (branch_id, canon_name), members in groups.items():
        keeper = members[0]
        keeper_id = str(keeper.id)

        # Rename keeper to canonical form if needed
        if keeper.name != canon_name:
            conn.execute(text(
                "UPDATE classes SET name = :name WHERE id = :id"
            ), {"name": canon_name, "id": keeper_id})

        # Reassign all FK references from duplicates to keeper, then delete
        for dup in members[1:]:
            dup_id = str(dup.id)

            # Reassign all FK references (discovered via information_schema query)
            for table in [
                "students",
                "branch_assignments",
                "class_diary_entries",
                "almanac_events",
                "daily_story_classes",
                "gallery_images",
                "homework",
                "syllabus",
            ]:
                conn.execute(text(
                    f"UPDATE {table} SET class_id = :keeper WHERE class_id = :dup"
                ), {"keeper": keeper_id, "dup": dup_id})

            # learning_module_assignment (class_id is varchar, not a real FK)
            conn.execute(text(
                "UPDATE learning_module_assignment SET class_id = :keeper WHERE class_id = :dup"
            ), {"keeper": keeper_id, "dup": dup_id})

            conn.execute(text(
                "DELETE FROM classes WHERE id = :dup"
            ), {"dup": dup_id})

    # Add unique constraint so duplicates can't be created again
    op.create_unique_constraint(
        'uq_class_branch_name', 'classes', ['branch_id', 'name']
    )


def downgrade() -> None:
    op.drop_constraint('uq_class_branch_name', 'classes', type_='unique')
