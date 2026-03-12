"""add fee_receipts table

Revision ID: 007_fee_receipts
Revises: 80e678e503d6
Create Date: 2026-03-12 00:00:00.000000
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = '007_fee_receipts'
down_revision: Union[str, None] = '80e678e503d6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    tables = set(inspector.get_table_names())
    if 'fee_receipts' not in tables:
        op.create_table(
            'fee_receipts',
            sa.Column('id', postgresql.UUID(as_uuid=True), primary_key=True),
            sa.Column('student_id', postgresql.UUID(as_uuid=True),
                      sa.ForeignKey('students.id', ondelete='CASCADE'), nullable=False),
            sa.Column('payment_id', postgresql.UUID(as_uuid=True),
                      sa.ForeignKey('fee_payments.id', ondelete='CASCADE'), nullable=False),
            sa.Column('student_name', sa.String(255), nullable=False),
            sa.Column('admission_number', sa.String(100), nullable=True),
            sa.Column('component', sa.String(50), nullable=False),
            sa.Column('component_label', sa.String(100), nullable=False),
            sa.Column('amount_paid', sa.Float, nullable=False),
            sa.Column('payment_mode', sa.String(50), nullable=False),
            sa.Column('payment_date', sa.DateTime, nullable=True),
            sa.Column('receipt_ref', sa.String(20), nullable=False),
            sa.Column('fee_data_json', sa.String(4000), nullable=True),
            sa.Column('created_at', sa.DateTime, server_default=sa.func.now()),
        )
        op.create_index('ix_fee_receipts_student_id', 'fee_receipts', ['student_id'])


def downgrade() -> None:
    op.drop_table('fee_receipts')
