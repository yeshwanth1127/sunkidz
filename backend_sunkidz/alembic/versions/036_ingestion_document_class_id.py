"""Add class_id to ingestion_documents (selected at upload time, same as the
manual admission form) so OCR results can be auto-applied without a manual
review step."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "036_ingestion_document_class_id"
down_revision = "035_ingestion_documents"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "ingestion_documents",
        sa.Column("class_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("classes.id"), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("ingestion_documents", "class_id")
