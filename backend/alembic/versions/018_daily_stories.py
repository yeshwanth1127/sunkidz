"""daily stories with branch/class scope

Revision ID: 018_daily_stories
Revises: 017_chat_message_attachments
Create Date: 2026-05-20

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "018_daily_stories"
down_revision = "017_chat_message_attachments"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "daily_stories",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("story_type", sa.String(20), nullable=False, server_default="daily"),
        sa.Column("media_kind", sa.String(20), nullable=False),
        sa.Column("file_path", sa.String(500), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_mime", sa.String(100), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_table(
        "daily_story_branches",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("story_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("daily_stories.id", ondelete="CASCADE"), nullable=False),
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("branches.id"), nullable=False),
    )
    op.create_index("ix_daily_story_branches_story_id", "daily_story_branches", ["story_id"])
    op.create_index("ix_daily_story_branches_branch_id", "daily_story_branches", ["branch_id"])
    op.create_table(
        "daily_story_classes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("story_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("daily_stories.id", ondelete="CASCADE"), nullable=False),
        sa.Column("class_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("classes.id"), nullable=False),
    )
    op.create_index("ix_daily_story_classes_story_id", "daily_story_classes", ["story_id"])
    op.create_index("ix_daily_story_classes_class_id", "daily_story_classes", ["class_id"])


def downgrade() -> None:
    op.drop_table("daily_story_classes")
    op.drop_table("daily_story_branches")
    op.drop_table("daily_stories")
