"""Add subject_name to learning_video."""
from alembic import op
import sqlalchemy as sa

revision = "026_add_subject_name_to_learning_video"
down_revision = "025_normalize_and_deduplicate_classes"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('learning_video', sa.Column('subject_name', sa.String(255), nullable=True))


def downgrade() -> None:
    op.drop_column('learning_video', 'subject_name')
