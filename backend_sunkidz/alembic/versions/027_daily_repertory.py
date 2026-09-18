"""Add daily_repertory and daily_repertory_slot tables."""
from alembic import op
import sqlalchemy as sa


revision = "027_daily_repertory"
down_revision = "026_day_folders"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "daily_repertory",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("class_id", sa.String(36), nullable=False),
        sa.Column("report_date", sa.Date(), nullable=False),
        sa.Column("created_by", sa.String(36), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=True),
        sa.Column("sent_to_parents", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("sent_at", sa.DateTime(), nullable=True),
        sa.UniqueConstraint("class_id", "report_date", name="uq_repertory_class_date"),
    )
    op.create_index(
        "ix_daily_repertory_class_date",
        "daily_repertory",
        ["class_id", "report_date"],
    )

    op.create_table(
        "daily_repertory_slot",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "repertory_id",
            sa.String(36),
            sa.ForeignKey("daily_repertory.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("timing", sa.String(100), nullable=False),
        sa.Column("description", sa.String(2000), nullable=True),
        sa.Column("slot_order", sa.Integer(), nullable=False, server_default="0"),
    )
    op.create_index(
        "ix_daily_repertory_slot_repertory",
        "daily_repertory_slot",
        ["repertory_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_daily_repertory_slot_repertory", table_name="daily_repertory_slot")
    op.drop_table("daily_repertory_slot")
    op.drop_index("ix_daily_repertory_class_date", table_name="daily_repertory")
    op.drop_table("daily_repertory")
