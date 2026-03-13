"""add custom_fields_json to fee_structures

Revision ID: 008_dynamic_fee_fields
Revises: 007_fee_receipts
Create Date: 2026-03-13 00:00:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = '008_dynamic_fee_fields'
down_revision: Union[str, None] = '007_fee_receipts'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    cols = {c['name'] for c in inspector.get_columns('fee_structures')}
    if 'custom_fields_json' not in cols:
        op.add_column(
            'fee_structures',
            sa.Column('custom_fields_json', sa.Text(), nullable=True),
        )


def downgrade() -> None:
    op.drop_column('fee_structures', 'custom_fields_json')
