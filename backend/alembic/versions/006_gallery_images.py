"""Add gallery images table

Revision ID: 006
Revises: 005
Create Date: 2026-03-08

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql
from sqlalchemy import inspect


revision: str = "006"
down_revision: Union[str, None] = "005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)

    if not inspector.has_table("gallery_images"):
        op.create_table(
            "gallery_images",
            sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("class_id", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("uploaded_by", postgresql.UUID(as_uuid=True), nullable=False),
            sa.Column("title", sa.String(length=255), nullable=True),
            sa.Column("description", sa.Text(), nullable=True),
            sa.Column("upload_date", sa.Date(), nullable=False),
            sa.Column("file_path", sa.String(length=500), nullable=False),
            sa.Column("file_name", sa.String(length=255), nullable=False),
            sa.Column("file_size", sa.String(length=50), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
            sa.ForeignKeyConstraint(["class_id"], ["classes.id"], ondelete="CASCADE"),
            sa.ForeignKeyConstraint(["uploaded_by"], ["users.id"], ondelete="CASCADE"),
            sa.PrimaryKeyConstraint("id"),
        )

    existing_indexes = {idx["name"] for idx in inspector.get_indexes("gallery_images")}
    index_name = op.f("ix_gallery_images_class_date")
    if index_name not in existing_indexes:
        op.create_index(index_name, "gallery_images", ["class_id", "upload_date"])


def downgrade() -> None:
    bind = op.get_bind()
    inspector = inspect(bind)
    if inspector.has_table("gallery_images"):
        existing_indexes = {idx["name"] for idx in inspector.get_indexes("gallery_images")}
        index_name = op.f("ix_gallery_images_class_date")
        if index_name in existing_indexes:
            op.drop_index(index_name, table_name="gallery_images")
        op.drop_table("gallery_images")
