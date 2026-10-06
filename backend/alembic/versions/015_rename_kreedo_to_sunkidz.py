"""rename branch system_type kreedo to sunkidz

Revision ID: 015_rename_kreedo_to_sunkidz
Revises: 014_branch_system_type
Create Date: 2026-05-19

"""
from alembic import op
import sqlalchemy as sa

revision = "015_rename_kreedo_to_sunkidz"
down_revision = "014_branch_system_type"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        "UPDATE branches SET system_type = 'sunkidz' WHERE system_type = 'kreedo'"
    )
    op.alter_column(
        "branches",
        "system_type",
        server_default="sunkidz",
        existing_type=sa.String(length=20),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.execute(
        "UPDATE branches SET system_type = 'kreedo' WHERE system_type = 'sunkidz'"
    )
    op.alter_column(
        "branches",
        "system_type",
        server_default="kreedo",
        existing_type=sa.String(length=20),
        existing_nullable=False,
    )
