"""branch gallery items (photos & videos)

Revision ID: 031_gallery_items
Revises: fa512c57da79, 030_add_missing_playgroup_classes
Create Date: 2026-08-27

Also acts as the merge point for the two open heads that predate it
(fa512c57da79 and 030_add_missing_playgroup_classes) so `alembic upgrade
head` resolves to a single head again. It only adds a new table -- no
existing table, column or data is touched.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "031_gallery_items"
down_revision = ("fa512c57da79", "030_add_missing_playgroup_classes")
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "gallery_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "branch_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("branches.id"),
            nullable=False,
        ),
        sa.Column(
            "uploaded_by",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id"),
            nullable=True,
        ),
        sa.Column("media_type", sa.String(20), nullable=False),
        sa.Column("title", sa.String(255), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("file_path", sa.String(500), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_mime", sa.String(100), nullable=True),
        sa.Column("file_size", sa.String(50), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_gallery_items_branch_id", "gallery_items", ["branch_id"])


def downgrade() -> None:
    op.drop_index("ix_gallery_items_branch_id", table_name="gallery_items")
    op.drop_table("gallery_items")
