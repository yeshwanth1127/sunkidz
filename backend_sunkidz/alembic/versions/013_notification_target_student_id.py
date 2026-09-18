"""add target_student_id to notifications

Revision ID: 013_notification_target_student_id
Revises: 012_syllabus_school_days_holidays
Create Date: 2026-04-16

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID


# revision identifiers, used by Alembic.
revision: str = "013_notification_target_student_id"
down_revision: Union[str, None] = "012_syllabus_school_days_holidays"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "notifications",
        sa.Column("target_student_id", UUID(as_uuid=True), sa.ForeignKey("students.id"), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("notifications", "target_student_id")
