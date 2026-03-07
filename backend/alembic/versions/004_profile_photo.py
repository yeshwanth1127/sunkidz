"""add_profile_photo_to_users

Revision ID: 004_profile_photo
Revises: 002
Create Date: 2026-03-05

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers used by Alembic
revision = '004_profile_photo'
down_revision = '003'
branch_labels = None
depends_on = None


def upgrade():
    # Add profile_photo column to users table
    op.add_column('users', sa.Column('profile_photo', sa.String(length=500), nullable=True))


def downgrade():
    # Remove profile_photo column from users table
    op.drop_column('users', 'profile_photo')
