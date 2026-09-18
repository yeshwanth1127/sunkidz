"""Add day_folder and day_folder_content tables."""
from alembic import op
import sqlalchemy as sa


revision = "026_day_folders"
down_revision = "025_normalize_and_deduplicate_classes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "day_folder",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("class_id", sa.String(36), nullable=False),
        sa.Column("school_day", sa.Integer(), nullable=False),
        sa.Column("academic_year_start", sa.Date(), nullable=False),
        sa.Column("created_by", sa.String(36), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint(
            "class_id", "school_day", "academic_year_start", "name",
            name="uq_day_folder_name",
        ),
    )
    op.create_index(
        "ix_day_folder_class_day",
        "day_folder",
        ["class_id", "school_day", "academic_year_start"],
    )

    op.create_table(
        "day_folder_content",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "folder_id",
            sa.String(36),
            sa.ForeignKey("day_folder.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("description", sa.String(1000), nullable=True),
        sa.Column("file_path", sa.String(500), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_size", sa.Integer(), nullable=False),
        sa.Column("content_type", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
    )
    op.create_index(
        "ix_day_folder_content_folder",
        "day_folder_content",
        ["folder_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_day_folder_content_folder", table_name="day_folder_content")
    op.drop_table("day_folder_content")
    op.drop_index("ix_day_folder_class_day", table_name="day_folder")
    op.drop_table("day_folder")
