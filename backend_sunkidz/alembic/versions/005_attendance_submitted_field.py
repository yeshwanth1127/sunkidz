"""Add submitted field to attendance tables.

Revision ID: 005
Revises: 80e678e503d6
Create Date: 2026-03-06

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '005'
down_revision = '80e678e503d6'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('attendances', sa.Column('submitted', sa.Boolean(), nullable=False, server_default='false'))
    op.add_column('staff_attendances', sa.Column('submitted', sa.Boolean(), nullable=False, server_default='false'))


def downgrade() -> None:
    op.drop_column('staff_attendances', 'submitted')
    op.drop_column('attendances', 'submitted')
