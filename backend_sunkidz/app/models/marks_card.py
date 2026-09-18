import uuid
from sqlalchemy import Column, String, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base


class MarksCard(Base):
    __tablename__ = "marks_cards"

    # Exactly one current card per (student, academic_year). Matches the unique
    # index created in migration 002 (and re-asserted in 032) so a table built
    # by `Base.metadata.create_all` also carries the invariant.
    __table_args__ = (
        Index(
            "ix_marks_cards_student_year",
            "student_id",
            "academic_year",
            unique=True,
        ),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("students.id", ondelete="CASCADE"), nullable=False)
    academic_year = Column(String(20), nullable=False)
    data = Column(JSONB, nullable=True)
    sent_to_parent_at = Column(DateTime(timezone=True), nullable=True)  # When sent to parent
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    student = relationship("Student", backref="marks_cards")
