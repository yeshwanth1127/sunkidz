"""per-student diary entries + global almanac events

Revision ID: 019_per_student_diary_global_events
Revises: 018_daily_stories
Create Date: 2026-05-21
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "019_per_student_diary_global_events"
down_revision = "018_daily_stories"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- class_diary_entries: per-student support ---------------------------
    with op.batch_alter_table("class_diary_entries") as batch:
        batch.add_column(
            sa.Column(
                "student_id",
                postgresql.UUID(as_uuid=True),
                sa.ForeignKey("students.id", ondelete="CASCADE"),
                nullable=True,
            )
        )

    # Drop the old (class_id, entry_date) unique constraint so we can have
    # one class-wide row + one row per student per day.
    op.execute(
        "ALTER TABLE class_diary_entries "
        "DROP CONSTRAINT IF EXISTS uq_class_diary_class_date"
    )

    # Partial unique indexes so that:
    #   * only one class-wide entry (student_id IS NULL) per class/day
    #   * only one entry per student per class/day
    op.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS uq_class_diary_class_date_null_student "
        "ON class_diary_entries (class_id, entry_date) "
        "WHERE student_id IS NULL"
    )
    op.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS uq_class_diary_class_date_student "
        "ON class_diary_entries (class_id, entry_date, student_id) "
        "WHERE student_id IS NOT NULL"
    )
    op.create_index(
        "ix_class_diary_student_id",
        "class_diary_entries",
        ["student_id"],
    )

    # --- almanac_events: global flag ---------------------------------------
    with op.batch_alter_table("almanac_events") as batch:
        batch.add_column(
            sa.Column(
                "is_global",
                sa.Boolean(),
                nullable=False,
                server_default=sa.text("false"),
            )
        )


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_class_diary_student_id")
    op.execute("DROP INDEX IF EXISTS uq_class_diary_class_date_student")
    op.execute("DROP INDEX IF EXISTS uq_class_diary_class_date_null_student")
    with op.batch_alter_table("class_diary_entries") as batch:
        batch.drop_column("student_id")
    op.execute(
        "ALTER TABLE class_diary_entries "
        "ADD CONSTRAINT uq_class_diary_class_date "
        "UNIQUE (class_id, entry_date)"
    )
    with op.batch_alter_table("almanac_events") as batch:
        batch.drop_column("is_global")
