"""Create learning_module and learning_video tables."""
from alembic import op
import sqlalchemy as sa


revision = "020_learning_modules"
down_revision = "019_per_student_diary_global_events"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create learning_module table
    op.create_table(
        'learning_module',
        sa.Column('id', sa.String(36), nullable=False),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('description', sa.String(1000), nullable=True),
        sa.Column('created_by', sa.String(36), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.Column('updated_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['created_by'], ['user.id'], ),
        sa.PrimaryKeyConstraint('id')
    )

    # Create learning_video table
    op.create_table(
        'learning_video',
        sa.Column('id', sa.String(36), nullable=False),
        sa.Column('module_id', sa.String(36), nullable=False),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('description', sa.String(1000), nullable=True),
        sa.Column('file_path', sa.String(500), nullable=False),
        sa.Column('file_name', sa.String(255), nullable=False),
        sa.Column('file_size', sa.Integer(), nullable=False),
        sa.Column('duration', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['module_id'], ['learning_module.id'], ),
        sa.PrimaryKeyConstraint('id')
    )

    # Create indexes
    op.create_index(op.f('ix_learning_module_created_by'), 'learning_module', ['created_by'], unique=False)
    op.create_index(op.f('ix_learning_video_module_id'), 'learning_video', ['module_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_learning_video_module_id'), table_name='learning_video')
    op.drop_index(op.f('ix_learning_module_created_by'), table_name='learning_module')
    op.drop_table('learning_video')
    op.drop_table('learning_module')
