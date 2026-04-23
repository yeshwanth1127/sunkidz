"""syllabus school_day and holidays

Revision ID: 012_syllabus_school_days_holidays
Revises: 011_notification_sender_id
Create Date: 2026-03-16

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision: str = "012_syllabus_school_days_holidays"
down_revision: Union[str, None] = "011_notification_sender_id"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "syllabus_holidays",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("academic_year_start", sa.Date(), nullable=False),
        sa.Column("holiday_date", sa.Date(), nullable=False),
        sa.Column("reason", sa.String(255), nullable=True),
        sa.Column("created_by", UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index(
        "ix_syllabus_holidays_year_date",
        "syllabus_holidays",
        ["academic_year_start", "holiday_date"],
        unique=True,
    )

    op.add_column(
        "syllabus",
        sa.Column("school_day", sa.Integer(), nullable=True),
    )
    op.add_column(
        "syllabus",
        sa.Column("academic_year_start", sa.Date(), nullable=True),
    )
    op.alter_column(
        "syllabus",
        "upload_date",
        existing_type=sa.Date(),
        nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "syllabus",
        "upload_date",
        existing_type=sa.Date(),
        nullable=False,
    )
    op.drop_column("syllabus", "academic_year_start")
    op.drop_column("syllabus", "school_day")
    op.drop_index("ix_syllabus_holidays_year_date", table_name="syllabus_holidays")
    op.drop_table("syllabus_holidays")
