"""Add school_day and academic_year_start to learning_video."""
from alembic import op
import sqlalchemy as sa


revision = "023_learning_video_fields"
down_revision = "022_learning_module_class_branch"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column('learning_video', sa.Column('school_day', sa.Integer(), nullable=True))
    op.add_column('learning_video', sa.Column('academic_year_start', sa.Date(), nullable=True))
    op.create_index(op.f('ix_learning_video_school_day'), 'learning_video', ['school_day'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_learning_video_school_day'), table_name='learning_video')
    op.drop_column('learning_video', 'academic_year_start')
    op.drop_column('learning_video', 'school_day')
