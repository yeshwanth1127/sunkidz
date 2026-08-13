"""Rename daily_repertory tables, indexes, constraints, and column to daily_report."""
from alembic import op


revision = "028_rename_daily_repertory_to_daily_report"
down_revision = "027_daily_repertory"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Rename slot table first (has FK into the parent table)
    op.rename_table("daily_repertory_slot", "daily_report_slot")
    op.rename_table("daily_repertory", "daily_report")

    # Rename indexes (PostgreSQL: ALTER INDEX ... RENAME TO ...)
    op.execute("ALTER INDEX IF EXISTS ix_daily_repertory_class_date RENAME TO ix_daily_report_class_date")
    op.execute("ALTER INDEX IF EXISTS ix_daily_repertory_slot_repertory RENAME TO ix_daily_report_slot_report")

    # Rename unique constraint on daily_report
    op.execute(
        "ALTER TABLE daily_report "
        "RENAME CONSTRAINT uq_repertory_class_date TO uq_report_class_date"
    )

    # Rename column repertory_id → report_id in daily_report_slot
    op.execute("ALTER TABLE daily_report_slot RENAME COLUMN repertory_id TO report_id")


def downgrade() -> None:
    op.execute("ALTER TABLE daily_report_slot RENAME COLUMN report_id TO repertory_id")
    op.execute(
        "ALTER TABLE daily_report "
        "RENAME CONSTRAINT uq_report_class_date TO uq_repertory_class_date"
    )
    op.execute("ALTER INDEX IF EXISTS ix_daily_report_slot_report RENAME TO ix_daily_repertory_slot_repertory")
    op.execute("ALTER INDEX IF EXISTS ix_daily_report_class_date RENAME TO ix_daily_repertory_class_date")
    op.rename_table("daily_report", "daily_repertory")
    op.rename_table("daily_report_slot", "daily_repertory_slot")
