from uuid import uuid4
from sqlalchemy import Column, String, DateTime, Date, Boolean, Integer, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base


class DailyReport(Base):
    __tablename__ = "daily_report"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    class_id = Column(String(36), nullable=False)
    report_date = Column(Date, nullable=False)
    created_by = Column(String(36), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    sent_to_parents = Column(Boolean, default=False, nullable=False)
    sent_at = Column(DateTime, nullable=True)

    slots = relationship(
        "DailyReportSlot",
        back_populates="report",
        cascade="all, delete-orphan",
        order_by="DailyReportSlot.slot_order",
    )

    __table_args__ = (
        UniqueConstraint("class_id", "report_date", name="uq_report_class_date"),
    )


class DailyReportSlot(Base):
    __tablename__ = "daily_report_slot"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    report_id = Column(
        String(36), ForeignKey("daily_report.id", ondelete="CASCADE"), nullable=False
    )
    timing = Column(String(100), nullable=False)
    description = Column(String(2000), nullable=True)
    slot_order = Column(Integer, nullable=False, default=0)

    report = relationship("DailyReport", back_populates="slots")
