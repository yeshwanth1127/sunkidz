from datetime import date, datetime
from typing import Optional, List
from uuid import UUID

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.auth import get_current_user
from app.core.database import get_db
from app.models import User, DailyReport, DailyReportSlot
from app.models.branch import BranchAssignment, Class
from app.models.student import Student, ParentStudentLink
from app.services import messaging_service
from app.services.excel_parser import parse_timetable_excel

router = APIRouter(prefix="/daily-report", tags=["daily-report"])


# ---------------------------------------------------------------------------
# Pydantic schemas
# ---------------------------------------------------------------------------

class SlotIn(BaseModel):
    timing: str
    description: Optional[str] = None
    slot_order: int = 0


class CreateReportIn(BaseModel):
    class_id: str
    report_date: date
    slots: List[SlotIn] = []


class UpdateReportIn(BaseModel):
    slots: List[SlotIn] = []


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _serialize(report: DailyReport) -> dict:
    return {
        "id": str(report.id),
        "class_id": report.class_id,
        "report_date": report.report_date.isoformat(),
        "created_by": report.created_by,
        "created_at": report.created_at.isoformat() if report.created_at else None,
        "updated_at": report.updated_at.isoformat() if report.updated_at else None,
        "sent_to_parents": report.sent_to_parents,
        "sent_at": report.sent_at.isoformat() if report.sent_at else None,
        "slots": [
            {
                "id": str(s.id),
                "timing": s.timing,
                "description": s.description,
                "slot_order": s.slot_order,
            }
            for s in report.slots
        ],
    }


def _check_class_access(user: User, class_id: str, db: Session) -> None:
    if user.role in ("admin", "coordinator"):
        return
    if user.role == "teacher":
        assignment = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == user.id,
            BranchAssignment.class_id == class_id,
        ).first()
        if not assignment:
            raise HTTPException(status_code=403, detail="You are not assigned to this class")
        return
    raise HTTPException(status_code=403, detail="Access denied")


def _get_parent_ids_for_class(class_id: str, db: Session) -> list:
    students = db.query(Student).filter(Student.class_id == class_id).all()
    student_ids = [s.id for s in students]
    if not student_ids:
        return []
    links = db.query(ParentStudentLink).filter(
        ParentStudentLink.student_id.in_(student_ids)
    ).all()
    seen = set()
    parent_ids = []
    for link in links:
        pid = link.user_id
        if pid not in seen:
            seen.add(pid)
            parent_ids.append(pid)
    return parent_ids


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/")
def get_report(
    class_id: str = Query(...),
    report_date: date = Query(..., alias="date"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the daily report for a class on a specific date. Returns null if none exists."""
    report = db.query(DailyReport).filter(
        DailyReport.class_id == class_id,
        DailyReport.report_date == report_date,
    ).first()
    if not report:
        return None
    return _serialize(report)


@router.get("/history")
def list_history(
    class_id: str = Query(...),
    limit: int = Query(10, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """List recent daily reports for a class (newest first)."""
    reports = (
        db.query(DailyReport)
        .filter(DailyReport.class_id == class_id)
        .order_by(DailyReport.report_date.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": str(r.id),
            "report_date": r.report_date.isoformat(),
            "sent_to_parents": r.sent_to_parents,
            "slot_count": len(r.slots),
        }
        for r in reports
    ]


@router.post("/")
def create_report(
    body: CreateReportIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Create a daily report with slots for a class on a date (admin/coordinator/teacher)."""
    _check_class_access(current_user, body.class_id, db)

    existing = db.query(DailyReport).filter(
        DailyReport.class_id == body.class_id,
        DailyReport.report_date == body.report_date,
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail="A report already exists for this class on this date. Use PUT to update it.",
        )

    report = DailyReport(
        class_id=body.class_id,
        report_date=body.report_date,
        created_by=str(current_user.id),
    )
    db.add(report)
    db.flush()

    for slot_in in body.slots:
        db.add(DailyReportSlot(
            report_id=report.id,
            timing=slot_in.timing,
            description=slot_in.description,
            slot_order=slot_in.slot_order,
        ))

    db.commit()
    db.refresh(report)
    return _serialize(report)


@router.put("/{report_id}")
def update_report(
    report_id: str,
    body: UpdateReportIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Replace all slots of an existing report."""
    report = db.query(DailyReport).filter(DailyReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    _check_class_access(current_user, report.class_id, db)

    for slot in list(report.slots):
        db.delete(slot)
    db.flush()

    for slot_in in body.slots:
        db.add(DailyReportSlot(
            report_id=report.id,
            timing=slot_in.timing,
            description=slot_in.description,
            slot_order=slot_in.slot_order,
        ))

    report.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(report)
    return _serialize(report)


@router.delete("/{report_id}")
def delete_report(
    report_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Delete a report and all its slots (admin/coordinator only)."""
    if current_user.role not in ("admin", "coordinator"):
        raise HTTPException(status_code=403, detail="Admin or coordinator access required")

    report = db.query(DailyReport).filter(DailyReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    db.delete(report)
    db.commit()
    return {"message": "Report deleted successfully"}


@router.post("/{report_id}/send-to-parents")
def send_to_parents(
    report_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Send the daily report as a push notification to all parents of the class."""
    report = db.query(DailyReport).filter(DailyReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")

    _check_class_access(current_user, report.class_id, db)

    class_ = db.query(Class).filter(Class.id == report.class_id).first()
    class_name = class_.name if class_ else "Class"

    parent_ids = _get_parent_ids_for_class(report.class_id, db)
    if not parent_ids:
        raise HTTPException(status_code=404, detail="No parents found for this class")

    slot_lines = [
        f"{s.timing}: {s.description or '—'}"
        for s in report.slots[:4]
    ]
    body_text = "\n".join(slot_lines)
    if len(report.slots) > 4:
        body_text += f"\n…and {len(report.slots) - 4} more"
    if len(body_text) > 250:
        body_text = body_text[:247] + "…"

    title = f"Daily Report – {class_name} ({report.report_date.strftime('%d %b %Y')})"

    count = messaging_service.create_notifications_for_users(
        db=db,
        recipient_ids=[UUID(str(pid)) for pid in parent_ids],
        title=title,
        message=body_text,
        sender_id=current_user.id,
    )
    db.commit()

    report.sent_to_parents = True
    report.sent_at = datetime.utcnow()
    db.commit()

    return {"message": f"Sent to {count} parent(s)", "parent_count": count}


@router.post("/parse-excel")
async def parse_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Upload a .xlsx timetable file.
    Returns detected grade, matched class (if found in DB), and extracted time slots.
    """
    if not file.filename or not file.filename.lower().endswith(".xlsx"):
        raise HTTPException(status_code=400, detail="Only .xlsx files are supported")

    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty")

    try:
        result = parse_timetable_excel(file_bytes)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc))

    detected_grade = result["detected_grade"]
    slots = result["slots"]

    matched_class_id = None
    matched_class_name = None

    if detected_grade:
        all_classes = db.query(Class).all()
        grade_lower = detected_grade.lower()

        for c in all_classes:
            if c.name.lower() == grade_lower:
                matched_class_id = str(c.id)
                matched_class_name = c.name
                break

        if not matched_class_id:
            for c in all_classes:
                if grade_lower in c.name.lower() or c.name.lower() in grade_lower:
                    matched_class_id = str(c.id)
                    matched_class_name = c.name
                    break

    return {
        "detected_grade": detected_grade,
        "matched_class_id": matched_class_id,
        "matched_class_name": matched_class_name,
        "slots": slots,
    }
