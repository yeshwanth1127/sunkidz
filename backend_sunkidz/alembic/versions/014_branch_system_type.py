"""add system_type to branches

Revision ID: 014_branch_system_type
Revises: 013_notification_target_student_id
Create Date: 2026-04-24

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "014_branch_system_type"
down_revision: Union[str, None] = "013_notification_target_student_id"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "branches",
        sa.Column("system_type", sa.String(length=20), nullable=False, server_default="kreedo"),
    )

    # Best-effort inference for existing data:
    # if a branch primarily has Nursery/LKG/UKG classes, mark it as normal.
    op.execute(
        """
        UPDATE branches b
        SET system_type = 'normal'
        WHERE EXISTS (
            SELECT 1
            FROM classes c
            WHERE c.branch_id = b.id
              AND lower(trim(c.name)) IN ('nursery', 'lkg', 'ukg')
        )
          AND NOT EXISTS (
            SELECT 1
            FROM classes c2
            WHERE c2.branch_id = b.id
              AND lower(replace(trim(c2.name), '-', '')) IN ('1g1', '1g2', '1g3')
        );
        """
    )

    op.alter_column("branches", "system_type", server_default=None)


def downgrade() -> None:
    op.drop_column("branches", "system_type")
