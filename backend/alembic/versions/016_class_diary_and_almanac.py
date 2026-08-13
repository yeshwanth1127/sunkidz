"""class diary entries, almanac events, branch holidays

Revision ID: 016_class_diary_and_almanac
Revises: 015_rename_kreedo_to_sunkidz
Create Date: 2026-05-19

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "016_class_diary_and_almanac"
down_revision = "015_rename_kreedo_to_sunkidz"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "class_diary_entries",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("class_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("classes.id"), nullable=False),
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("branches.id"), nullable=False),
        sa.Column("author_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("entry_date", sa.Date(), nullable=False),
        sa.Column("remarks", sa.Text(), nullable=True),
        sa.Column("activities", sa.Text(), nullable=True),
        sa.Column("homework_notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("class_id", "entry_date", name="uq_class_diary_class_date"),
    )
    op.create_index("ix_class_diary_entries_class_id", "class_diary_entries", ["class_id"])
    op.create_index("ix_class_diary_entries_branch_id", "class_diary_entries", ["branch_id"])
    op.create_index("ix_class_diary_entries_entry_date", "class_diary_entries", ["entry_date"])

    op.add_column(
        "syllabus_holidays",
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("branches.id"), nullable=True),
    )
    op.create_index("ix_syllabus_holidays_branch_id", "syllabus_holidays", ["branch_id"])

    op.create_table(
        "almanac_events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("branches.id"), nullable=False),
        sa.Column("class_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("classes.id"), nullable=True),
        sa.Column("academic_year_start", sa.Date(), nullable=False),
        sa.Column("event_date", sa.Date(), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("event_type", sa.String(50), nullable=False, server_default="event"),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_almanac_events_branch_id", "almanac_events", ["branch_id"])
    op.create_index("ix_almanac_events_event_date", "almanac_events", ["event_date"])


def downgrade() -> None:
    op.drop_table("almanac_events")
    op.drop_index("ix_syllabus_holidays_branch_id", table_name="syllabus_holidays")
    op.drop_column("syllabus_holidays", "branch_id")
    op.drop_table("class_diary_entries")
