"""add date_of_birth to users for toddlers/daycare login

Revision ID: 009_user_date_of_birth
Revises: 008_dynamic_fee_fields
Create Date: 2026-03-13 00:00:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "009_user_date_of_birth"
down_revision: Union[str, None] = "008_dynamic_fee_fields"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("date_of_birth", sa.Date(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "date_of_birth")
