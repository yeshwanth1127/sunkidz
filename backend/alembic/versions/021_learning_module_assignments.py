"""Add student-specific learning module assignments."""
from alembic import op
import sqlalchemy as sa


revision = "021_learning_module_assignments"
down_revision = "020_learning_modules"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create learning_module_assignment table
    op.create_table(
        'learning_module_assignment',
        sa.Column('id', sa.String(36), nullable=False),
        sa.Column('module_id', sa.String(36), nullable=False),
        sa.Column('student_id', sa.String(36), nullable=False),
        sa.Column('assigned_by', sa.String(36), nullable=False),
        sa.Column('assigned_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['module_id'], ['learning_module.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['student_id'], ['student.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['assigned_by'], ['user.id'], ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('module_id', 'student_id', name='uq_module_student_assignment')
    )

    # Create indexes
    op.create_index(op.f('ix_learning_module_assignment_student_id'), 'learning_module_assignment', ['student_id'], unique=False)
    op.create_index(op.f('ix_learning_module_assignment_module_id'), 'learning_module_assignment', ['module_id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_learning_module_assignment_module_id'), table_name='learning_module_assignment')
    op.drop_index(op.f('ix_learning_module_assignment_student_id'), table_name='learning_module_assignment')
    op.drop_table('learning_module_assignment')
