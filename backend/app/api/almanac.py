from datetime import date
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import get_current_user
from app.models.user import User
from app.models.branch import Class, Branch, BranchAssignment
from app.models.syllabus import Syllabus
from app.models.syllabus_holiday import SyllabusHoliday
from app.models.almanac_event import AlmanacEvent
from app.schemas.almanac import (
    AlmanacHolidayCreate,
    AlmanacHolidayResponse,
    AlmanacEventCreate,
    AlmanacEventUpdate,
    AlmanacEventResponse,
    AlmanacCalendarResponse,
    AlmanacCalendarDay,
)
from app.services.academic_calendar_service import (
    get_academic_year_for_date,
    get_academic_year_str,
    academic_year_start,
    get_school_days_with_dates,
)
from app.services.class_access import can_view_class

router = APIRouter(prefix="/almanac", tags=["almanac"])


def _coordinator_branch_id(user: User, db: Session) -> UUID | None:
    a = db.query(BranchAssignment).filter(
        BranchAssignment.user_id == user.id,
        BranchAssignment.class_id.is_(None),
    ).first()
    return a.branch_id if a else None


def _can_manage_branch(db: Session, user: User, branch_id: UUID | None) -> bool:
    if user.role == "admin":
        return True
    if user.role == "coordinator":
        if branch_id is None:
            return False
        cid = _coordinator_branch_id(user, db)
        return cid == branch_id
    return False


def _branch_name(db: Session, bid: UUID | None) -> str | None:
    if bid is None:
        return None
    b = db.query(Branch).filter(Branch.id == bid).first()
    return b.name if b else None


def _class_name(db: Session, cid: UUID | None) -> str | None:
    if cid is None:
        return None
    c = db.query(Class).filter(Class.id == cid).first()
    return c.name if c else None


def _serialize_event(db: Session, e: AlmanacEvent) -> "AlmanacEventResponse":
    return AlmanacEventResponse(
        id=str(e.id),
        branch_id=str(e.branch_id) if e.branch_id else "",
        branch_name=_branch_name(db, e.branch_id),
        class_id=str(e.class_id) if e.class_id else None,
        class_name=_class_name(db, e.class_id),
        event_date=e.event_date.isoformat(),
        title=e.title,
        description=e.description,
        event_type=e.event_type,
        is_global=bool(getattr(e, "is_global", False)),
        academic_year_start=e.academic_year_start.isoformat(),
    )


def _serialize_holiday(db: Session, h: SyllabusHoliday) -> "AlmanacHolidayResponse":
    return AlmanacHolidayResponse(
        id=str(h.id),
        holiday_date=h.holiday_date.isoformat(),
        reason=h.reason,
        branch_id=str(h.branch_id) if h.branch_id else None,
        branch_name=_branch_name(db, h.branch_id),
        is_global=h.branch_id is None,
        academic_year_start=h.academic_year_start.isoformat(),
    )


def _holiday_dates_for_branch(
    db: Session, start_year: int, branch_id: UUID
) -> set[date]:
    june1 = academic_year_start(start_year)
    rows = db.query(SyllabusHoliday).filter(
        SyllabusHoliday.academic_year_start == june1,
    ).all()
    out = set()
    for r in rows:
        if r.branch_id is None or r.branch_id == branch_id:
            out.add(r.holiday_date)
    return out


@router.get("/calendar", response_model=AlmanacCalendarResponse)
def get_almanac_calendar(
    branch_id: UUID = Query(...),
    class_id: Optional[UUID] = Query(None),
    academic_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if class_id and not can_view_class(db, user, class_id):
        raise HTTPException(status_code=403, detail="No permission for this class")
    if user.role == "coordinator":
        cid = _coordinator_branch_id(user, db)
        if cid and cid != branch_id:
            raise HTTPException(status_code=403, detail="Branch not in your scope")

    if academic_year is None:
        start_year, _ = get_academic_year_for_date(date.today())
    else:
        start_year = academic_year

    june1 = academic_year_start(start_year)
    holiday_set = _holiday_dates_for_branch(db, start_year, branch_id)
    school_days = get_school_days_with_dates(start_year, holiday_set)

    holidays_q = db.query(SyllabusHoliday).filter(
        SyllabusHoliday.academic_year_start == june1,
    )
    # Include events for this branch + any globally-broadcast events.
    events_q = db.query(AlmanacEvent).filter(
        AlmanacEvent.academic_year_start == june1,
        (AlmanacEvent.branch_id == branch_id) | (AlmanacEvent.is_global.is_(True)),
    )
    if class_id:
        events_q = events_q.filter(
            (AlmanacEvent.class_id == class_id) | (AlmanacEvent.class_id.is_(None))
        )

    all_holidays = holidays_q.all()
    all_events = events_q.all()
    syllabus_q = db.query(Syllabus).filter(Syllabus.academic_year_start == june1)
    if class_id:
        syllabus_q = syllabus_q.filter(Syllabus.class_id == class_id)
    else:
        class_ids = [c.id for c in db.query(Class).filter(Class.branch_id == branch_id).all()]
        if class_ids:
            syllabus_q = syllabus_q.filter(Syllabus.class_id.in_(class_ids))
    syllabi = syllabus_q.all()
    syllabus_by_day: dict[int, int] = {}
    for s in syllabi:
        syllabus_by_day[s.school_day] = syllabus_by_day.get(s.school_day, 0) + 1

    days: list[AlmanacCalendarDay] = []
    for sd in school_days:
        d = date.fromisoformat(sd["date"])
        day_holidays = [
            _serialize_holiday(db, h)
            for h in all_holidays
            if h.holiday_date == d
            and (h.branch_id is None or h.branch_id == branch_id)
        ]
        day_events = [
            _serialize_event(db, e)
            for e in all_events
            if e.event_date == d
        ]
        days.append(
            AlmanacCalendarDay(
                day=sd["day"],
                date=sd["date"],
                syllabus_count=syllabus_by_day.get(sd["day"], 0),
                holidays=day_holidays,
                events=day_events,
            )
        )

    return AlmanacCalendarResponse(
        branch_id=str(branch_id),
        class_id=str(class_id) if class_id else None,
        academic_year=get_academic_year_str(june1),
        academic_year_start=june1.isoformat(),
        days=days,
    )


@router.post("/holidays", response_model=AlmanacHolidayResponse)
def add_branch_holiday(
    data: AlmanacHolidayCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if data.branch_id and not _can_manage_branch(db, user, data.branch_id):
        raise HTTPException(status_code=403, detail="Not allowed")
    if user.role != "admin" and not data.branch_id:
        raise HTTPException(status_code=403, detail="Coordinators must set branch_id")

    if data.academic_year_start:
        ay = data.academic_year_start
    else:
        start_year, _ = get_academic_year_for_date(data.holiday_date)
        ay = academic_year_start(start_year)
    if ay.month != 6 or ay.day != 1:
        raise HTTPException(status_code=400, detail="academic_year_start must be June 1")

    row = SyllabusHoliday(
        academic_year_start=ay,
        holiday_date=data.holiday_date,
        reason=data.reason,
        branch_id=data.branch_id,
        created_by=user.id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _serialize_holiday(db, row)


@router.get("/holidays", response_model=List[AlmanacHolidayResponse])
def list_holidays(
    branch_id: Optional[UUID] = Query(None),
    academic_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if academic_year is None:
        start_year, _ = get_academic_year_for_date(date.today())
    else:
        start_year = academic_year
    june1 = academic_year_start(start_year)
    q = db.query(SyllabusHoliday).filter(SyllabusHoliday.academic_year_start == june1)
    if branch_id:
        q = q.filter(
            (SyllabusHoliday.branch_id == branch_id)
            | (SyllabusHoliday.branch_id.is_(None))
        )
    rows = q.order_by(SyllabusHoliday.holiday_date).all()
    return [_serialize_holiday(db, r) for r in rows]


@router.delete("/holidays/{holiday_id}")
def delete_branch_holiday(
    holiday_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    row = db.query(SyllabusHoliday).filter(SyllabusHoliday.id == holiday_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Holiday not found")
    # Global holidays (branch_id=None) require admin.
    if row.branch_id is None:
        if user.role != "admin":
            raise HTTPException(status_code=403, detail="Only admin can manage global holidays")
    elif not _can_manage_branch(db, user, row.branch_id):
        raise HTTPException(status_code=403, detail="Not allowed")
    db.delete(row)
    db.commit()
    return {"ok": True}


@router.get("/events", response_model=List[AlmanacEventResponse])
def list_events(
    branch_id: Optional[UUID] = Query(None),
    academic_year: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if academic_year is None:
        start_year, _ = get_academic_year_for_date(date.today())
    else:
        start_year = academic_year
    june1 = academic_year_start(start_year)
    q = db.query(AlmanacEvent).filter(AlmanacEvent.academic_year_start == june1)
    if branch_id:
        q = q.filter(
            (AlmanacEvent.branch_id == branch_id) | (AlmanacEvent.is_global.is_(True))
        )
    rows = q.order_by(AlmanacEvent.event_date).all()
    return [_serialize_event(db, r) for r in rows]


@router.post("/events", response_model=AlmanacEventResponse)
def create_event(
    data: AlmanacEventCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    # Global events broadcast to every branch — admin only.
    if data.is_global:
        if user.role != "admin":
            raise HTTPException(
                status_code=403,
                detail="Only admin can publish global events",
            )
        if data.class_id is not None:
            raise HTTPException(
                status_code=400,
                detail="Global events cannot be tied to a single class",
            )
        # We still need a branch_id on the row (column is NOT NULL); pick any
        # branch so the FK is satisfied — visibility is driven by is_global.
        any_branch = db.query(Branch).order_by(Branch.name).first()
        if not any_branch:
            raise HTTPException(status_code=400, detail="No branches exist yet")
        branch_id = any_branch.id
    else:
        if data.branch_id is None:
            raise HTTPException(
                status_code=400,
                detail="branch_id is required for non-global events",
            )
        if not _can_manage_branch(db, user, data.branch_id):
            raise HTTPException(status_code=403, detail="Not allowed")
        branch_id = data.branch_id

    if data.academic_year_start:
        ay = data.academic_year_start
    else:
        start_year, _ = get_academic_year_for_date(data.event_date)
        ay = academic_year_start(start_year)

    row = AlmanacEvent(
        branch_id=branch_id,
        class_id=data.class_id,
        academic_year_start=ay,
        event_date=data.event_date,
        title=data.title,
        description=data.description,
        event_type=data.event_type,
        is_global=data.is_global,
        created_by=user.id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _serialize_event(db, row)


@router.delete("/events/{event_id}")
def delete_event(
    event_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    row = db.query(AlmanacEvent).filter(AlmanacEvent.id == event_id).first()
    if not row:
        raise HTTPException(status_code=404, detail="Event not found")
    if getattr(row, "is_global", False):
        if user.role != "admin":
            raise HTTPException(
                status_code=403,
                detail="Only admin can delete global events",
            )
    elif not _can_manage_branch(db, user, row.branch_id):
        raise HTTPException(status_code=403, detail="Not allowed")
    db.delete(row)
    db.commit()
    return {"ok": True}
