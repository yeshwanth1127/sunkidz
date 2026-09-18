"""Add ingestion_documents table for n8n-powered admission-form digitization."""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "035_ingestion_documents"
down_revision = "034_school_calendar"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ingestion_documents",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("branches.id"), nullable=False),
        sa.Column("doc_type", sa.String(50), nullable=False, server_default="admission_form"),
        sa.Column("status", sa.String(20), nullable=False, server_default="pending"),
        sa.Column("file_path", sa.String(500), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_mime", sa.String(100), nullable=True),
        sa.Column("file_size", sa.String(50), nullable=True),
        sa.Column("uploaded_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("raw_ocr_data", postgresql.JSONB(), nullable=True),
        sa.Column("extracted_data", postgresql.JSONB(), nullable=True),
        sa.Column("confidence_scores", postgresql.JSONB(), nullable=True),
        sa.Column("matched_student_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("students.id"), nullable=True),
        sa.Column("matched_parent_user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("reviewed_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index(
        "ix_ingestion_documents_branch_status",
        "ingestion_documents",
        ["branch_id", "status"],
    )


def downgrade() -> None:
    op.drop_index("ix_ingestion_documents_branch_status", table_name="ingestion_documents")
    op.drop_table("ingestion_documents")
