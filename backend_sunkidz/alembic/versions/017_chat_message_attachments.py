"""chat message attachments

Revision ID: 017_chat_message_attachments
Revises: 016_class_diary_and_almanac
Create Date: 2026-05-19

"""
from alembic import op
import sqlalchemy as sa

revision = "017_chat_message_attachments"
down_revision = "016_class_diary_and_almanac"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("messages", sa.Column("attachment_path", sa.String(length=500), nullable=True))
    op.add_column("messages", sa.Column("attachment_name", sa.String(length=255), nullable=True))
    op.add_column("messages", sa.Column("attachment_mime", sa.String(length=100), nullable=True))
    op.add_column("messages", sa.Column("attachment_kind", sa.String(length=20), nullable=True))


def downgrade() -> None:
    op.drop_column("messages", "attachment_kind")
    op.drop_column("messages", "attachment_mime")
    op.drop_column("messages", "attachment_name")
    op.drop_column("messages", "attachment_path")
