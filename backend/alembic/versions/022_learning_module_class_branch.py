"""Update learning_module_assignment to use class/branch instead of student.

Revision ID: 022_learning_module_class_branch
Revises: 021_learning_module_assignments
Create Date: 2026-05-26

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '022_learning_module_class_branch'
down_revision = '021_learning_module_assignments'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Drop the old student_id column constraint
    op.drop_constraint('learning_module_assignment_student_id_fkey', 'learning_module_assignment', type_='foreignkey')
    op.drop_column('learning_module_assignment', 'student_id')
    
    # Add class_id and branch_id columns
    op.add_column('learning_module_assignment', sa.Column('class_id', sa.String(36), nullable=True))
    op.add_column('learning_module_assignment', sa.Column('branch_id', sa.String(36), nullable=True))
    
    # Add foreign keys
    op.create_foreign_key('learning_module_assignment_class_id_fkey', 'learning_module_assignment', 'class', ['class_id'], ['id'])
    op.create_foreign_key('learning_module_assignment_branch_id_fkey', 'learning_module_assignment', 'branch', ['branch_id'], ['id'])
    
    # Create unique constraint to prevent duplicate assignments
    op.create_unique_constraint('uq_module_class', 'learning_module_assignment', ['module_id', 'class_id'])
    op.create_unique_constraint('uq_module_branch', 'learning_module_assignment', ['module_id', 'branch_id'])


def downgrade() -> None:
    # Drop constraints
    op.drop_constraint('uq_module_branch', 'learning_module_assignment', type_='unique')
    op.drop_constraint('uq_module_class', 'learning_module_assignment', type_='unique')
    op.drop_constraint('learning_module_assignment_branch_id_fkey', 'learning_module_assignment', type_='foreignkey')
    op.drop_constraint('learning_module_assignment_class_id_fkey', 'learning_module_assignment', type_='foreignkey')
    
    # Remove columns
    op.drop_column('learning_module_assignment', 'branch_id')
    op.drop_column('learning_module_assignment', 'class_id')
    
    # Re-add student_id
    op.add_column('learning_module_assignment', sa.Column('student_id', sa.String(36), nullable=False))
    op.create_foreign_key('learning_module_assignment_student_id_fkey', 'learning_module_assignment', 'students', ['student_id'], ['id'])
