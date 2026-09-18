"""Add school_calendar_day table (synced from the school Google Sheet)."""
from alembic import op
import sqlalchemy as sa


revision = "034_school_calendar"
down_revision = "033_topup_standard_classes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "school_calendar_day",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("academic_year_start", sa.Date(), nullable=False),
        sa.Column("branch_scope", sa.String(36), nullable=False, server_default=""),
        sa.Column("calendar_date", sa.Date(), nullable=False),
        sa.Column("weekday", sa.String(10), nullable=True),
        sa.Column("is_working_day", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("learning_day", sa.Integer(), nullable=True),
        sa.Column("sheet_day_number", sa.Integer(), nullable=True),
        sa.Column("label", sa.String(500), nullable=True),
        sa.Column("category", sa.String(50), nullable=True),
        sa.Column("school_event", sa.String(500), nullable=True),
        sa.Column("document_numbers", sa.String(1000), nullable=True),
        sa.Column("document_availability", sa.String(255), nullable=True),
        sa.Column("synced_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint(
            "academic_year_start",
            "branch_scope",
            "calendar_date",
            name="uq_school_calendar_day",
        ),
    )
    op.create_index(
        "ix_school_calendar_day_lookup",
        "school_calendar_day",
        ["academic_year_start", "branch_scope"],
    )


def downgrade() -> None:
    op.drop_index("ix_school_calendar_day_lookup", table_name="school_calendar_day")
    op.drop_table("school_calendar_day")
