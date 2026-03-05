"""Initial schema

Revision ID: 001
Revises:
Create Date: 2025-03-04

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "branches",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("address", sa.String(500), nullable=True),
        sa.Column("contact_no", sa.String(50), nullable=True),
        sa.Column("status", sa.String(50), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "classes",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("academic_year", sa.String(20), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.ForeignKeyConstraint(["branch_id"], ["branches.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "enquiries",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("child_name", sa.String(255), nullable=False),
        sa.Column("date_of_birth", sa.Date(), nullable=True),
        sa.Column("age_years", sa.Integer(), nullable=True),
        sa.Column("age_months", sa.Integer(), nullable=True),
        sa.Column("gender", sa.String(20), nullable=True),
        sa.Column("father_name", sa.String(255), nullable=True),
        sa.Column("father_occupation", sa.String(255), nullable=True),
        sa.Column("father_place_of_work", sa.String(255), nullable=True),
        sa.Column("father_email", sa.String(255), nullable=True),
        sa.Column("father_contact_no", sa.String(50), nullable=True),
        sa.Column("mother_name", sa.String(255), nullable=True),
        sa.Column("mother_occupation", sa.String(255), nullable=True),
        sa.Column("mother_place_of_work", sa.String(255), nullable=True),
        sa.Column("mother_email", sa.String(255), nullable=True),
        sa.Column("mother_contact_no", sa.String(50), nullable=True),
        sa.Column("siblings_info", sa.Text(), nullable=True),
        sa.Column("siblings_age", sa.String(100), nullable=True),
        sa.Column("residential_address", sa.Text(), nullable=True),
        sa.Column("residential_contact_no", sa.String(50), nullable=True),
        sa.Column("challenges_specialities", sa.Text(), nullable=True),
        sa.Column("expectations_from_school", sa.Text(), nullable=True),
        sa.Column("signature_date", sa.Date(), nullable=True),
        sa.Column("status", sa.String(50), nullable=True),
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["branch_id"], ["branches.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("password_hash", sa.String(255), nullable=True),
        sa.Column("full_name", sa.String(255), nullable=False),
        sa.Column("role", sa.String(50), nullable=False),
        sa.Column("phone", sa.String(50), nullable=True),
        sa.Column("is_active", sa.String(10), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_table(
        "branch_assignments",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("class_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.ForeignKeyConstraint(["branch_id"], ["branches.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["class_id"], ["classes.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_table(
        "students",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("admission_number", sa.String(50), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("date_of_birth", sa.Date(), nullable=False),
        sa.Column("age_years", sa.Integer(), nullable=True),
        sa.Column("age_months", sa.Integer(), nullable=True),
        sa.Column("gender", sa.String(20), nullable=True),
        sa.Column("place_of_birth", sa.String(255), nullable=True),
        sa.Column("nationality", sa.String(100), nullable=True),
        sa.Column("mother_tongue", sa.String(100), nullable=True),
        sa.Column("blood_group", sa.String(20), nullable=True),
        sa.Column("medical_allergies", sa.Text(), nullable=True),
        sa.Column("medical_surgeries", sa.Text(), nullable=True),
        sa.Column("medical_chronic_illness", sa.Text(), nullable=True),
        sa.Column("class_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("branch_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("enquiry_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("photo_path", sa.String(500), nullable=True),
        sa.Column("residential_address", sa.Text(), nullable=True),
        sa.Column("residential_contact_no", sa.String(50), nullable=True),
        sa.Column("attended_previously", sa.Boolean(), nullable=True),
        sa.Column("school_daycare_name", sa.String(255), nullable=True),
        sa.Column("prev_school_duration", sa.String(100), nullable=True),
        sa.Column("prev_school_class", sa.String(50), nullable=True),
        sa.Column("birth_certificate", sa.Boolean(), nullable=True),
        sa.Column("immunization_record", sa.Boolean(), nullable=True),
        sa.Column("transfer_certificate", sa.Boolean(), nullable=True),
        sa.Column("passport_photos", sa.Boolean(), nullable=True),
        sa.Column("progress_report", sa.Boolean(), nullable=True),
        sa.Column("passport", sa.Boolean(), nullable=True),
        sa.Column("other_medical_report", sa.Boolean(), nullable=True),
        sa.Column("declaration_date", sa.Date(), nullable=True),
        sa.Column("parent_signature_path", sa.String(500), nullable=True),
        sa.Column("office_date", sa.Date(), nullable=True),
        sa.Column("school_rep_signature_path", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.ForeignKeyConstraint(["branch_id"], ["branches.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["class_id"], ["classes.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["enquiry_id"], ["enquiries.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_students_admission_number"), "students", ["admission_number"], unique=True)
    op.create_table(
        "parent_student_links",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("student_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("is_primary", sa.Boolean(), nullable=True),
        sa.ForeignKeyConstraint(["student_id"], ["students.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("parent_student_links")
    op.drop_index(op.f("ix_students_admission_number"), table_name="students")
    op.drop_table("students")
    op.drop_table("branch_assignments")
    op.drop_index(op.f("ix_users_email"), table_name="users")
    op.drop_table("users")
    op.drop_table("enquiries")
    op.drop_table("classes")
    op.drop_table("branches")
