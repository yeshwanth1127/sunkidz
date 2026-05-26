"""add branch_type to branches

Revision ID: 011_add_branch_type
Revises: 011_notification_sender_id
Create Date: 2026-04-23

"""
from alembic import op
import sqlalchemy as sa

revision = '011_add_branch_type'
down_revision = '011_notification_sender_id'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        'branches',
        sa.Column('branch_type', sa.String(20), nullable=True, server_default='normal'),
    )
    # Set existing branches to 'normal' type
    op.execute("UPDATE branches SET branch_type = 'normal' WHERE branch_type IS NULL")


def downgrade():
    op.drop_column('branches', 'branch_type')
