"""merge migration heads

Revision ID: fa512c57da79
Revises: 011_add_branch_type, 029_unify_grade_names_no_legacy
Create Date: 2026-08-26 20:43:15.013907

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'fa512c57da79'
down_revision: Union[str, None] = ('011_add_branch_type', '029_unify_grade_names_no_legacy')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
