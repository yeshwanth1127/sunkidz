"""Guarantee one current Marks Card per (student, academic_year)

Revision ID: 032_marks_card_single_current
Revises: 031_gallery_items
Create Date: 2026-09-02

Migration 002 already created a UNIQUE index on
(student_id, academic_year), but ``Base.metadata.create_all`` (run on
startup) could re-create the table without it on some environments, which
allowed stale duplicate rows to build up. This migration:

  1. collapses any existing duplicates down to the single most-recently
     touched row per (student_id, academic_year), and
  2. re-asserts the unique index (idempotent).

Only duplicate rows are removed; the current card and its data are kept.
"""
from alembic import op

revision = "032_marks_card_single_current"
down_revision = "031_gallery_items"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute(
        """
        DELETE FROM marks_cards
        WHERE id IN (
            SELECT id FROM (
                SELECT id,
                       ROW_NUMBER() OVER (
                           PARTITION BY student_id, academic_year
                           ORDER BY COALESCE(updated_at, created_at) DESC NULLS LAST,
                                    created_at DESC NULLS LAST,
                                    id DESC
                       ) AS rn
                FROM marks_cards
            ) ranked
            WHERE ranked.rn > 1
        )
        """
    )
    op.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS ix_marks_cards_student_year "
        "ON marks_cards (student_id, academic_year)"
    )


def downgrade() -> None:
    # The single-current-version invariant is intentionally kept; nothing to undo.
    pass
