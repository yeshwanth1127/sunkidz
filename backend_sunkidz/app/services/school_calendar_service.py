"""Turn the school's Google Sheet into a working-day / Learning Day calendar.

The sheet's **"Day #" column is the source of truth for working days**: a date
is a working day iff that cell holds a number. Weekends and holidays leave it
blank and therefore never receive a Learning Day number.

The Learning Day number is **recomputed** here as a running count of working
days (it normally equals the sheet's own "Day #"). Recomputing means the school
can turn a working day into a holiday just by blanking one cell — the following
days renumber automatically, with no need to hand-edit 200 rows.

Pure parsing/compute functions have no DB or network dependency and are unit
tested directly. ``sync`` / ``get_calendar`` add IO on top.
"""
from __future__ import annotations

import json
import logging
import re
import threading
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Iterable, List, Optional, Sequence

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.school_calendar import ALL_BRANCHES, SchoolCalendarDay
from app.services.google_sheets_client import fetch_tab_rows, SheetConfigError

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Column detection / value parsing
# ---------------------------------------------------------------------------

_MONTHS = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}

_HEADER_KEYS = {
    "date": ("date",),
    "day": ("day",),
    "day_number": ("day #", "day#", "day no", "day number", "learning day"),
    "description": ("description",),
    "category": ("holiday / celebration", "holiday/celebration", "holiday", "celebration"),
    "school_event": ("school event",),
    "doc_number": ("document number", "document no", "doc number"),
    "doc_availability": ("document availability", "document avail", "doc availability"),
}


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", (s or "").strip().lower())


def parse_sheet_date(value: str) -> Optional[date]:
    """Parse the many date shapes the sheet uses.

    Handles ``2026-06-01``, ``2026-06-01 00:00:00``, ``1-Jun-26``,
    ``1-Jun-2026``, ``01/06/2026`` and ``1 June 2026``.
    """
    v = (value or "").strip()
    if not v:
        return None
    # ISO (optionally with time)
    m = re.match(r"^(\d{4})-(\d{2})-(\d{2})", v)
    if m:
        try:
            return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
        except ValueError:
            return None
    # d-Mon-yy / d Mon yyyy / d/Mon/yy
    m = re.match(r"^(\d{1,2})[-/ ]([A-Za-z]{3,})[-/ ](\d{2,4})$", v)
    if m:
        mon = _MONTHS.get(m.group(2)[:3].lower())
        if mon:
            year = int(m.group(3))
            if year < 100:
                year += 2000
            try:
                return date(year, mon, int(m.group(1)))
            except ValueError:
                return None
    # dd/mm/yyyy or dd-mm-yyyy
    m = re.match(r"^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$", v)
    if m:
        year = int(m.group(3))
        if year < 100:
            year += 2000
        try:
            return date(year, int(m.group(2)), int(m.group(1)))
        except ValueError:
            return None
    return None


def parse_day_number(value: str) -> Optional[int]:
    """Return the integer Day # or None when the cell is blank/non-numeric.

    Tolerates ``"12"``, ``"12.0"`` and a stray Excel date serial that
    spreadsheet software sometimes formats a plain number as.
    """
    v = (value or "").strip()
    if not v:
        return None
    try:
        f = float(v)
        if f > 0:
            return int(round(f))
    except ValueError:
        pass
    # Spreadsheet software sometimes formats a small integer as a date. e.g.
    # Day # 102 shows up as "11-Apr-00" / "1900-04-11" (Excel's 1900 epoch).
    m = re.match(r"^(\d{1,2})[-/ ]([A-Za-z]{3,})[-/ ](\d{2,4})$", v)
    if m:
        mon = _MONTHS.get(m.group(2)[:3].lower())
        yr = int(m.group(3))
        if mon and yr in (0, 1900, 2000):
            try:
                serial = (date(1900, mon, int(m.group(1))) - date(1899, 12, 30)).days
                if 0 < serial < 1000:
                    return serial
            except ValueError:
                pass
    d = parse_sheet_date(v)
    if d is not None and d.year <= 1901:
        serial = (d - date(1899, 12, 30)).days
        if 0 < serial < 1000:
            return serial
    return None


def academic_year_start_for(d: date) -> date:
    """June 1 of the academic year containing ``d`` (June -> March)."""
    return date(d.year if d.month >= 6 else d.year - 1, 6, 1)


def normalize_category(raw: str, is_working_day: bool) -> Optional[str]:
    r = _norm(raw)
    if not r:
        return "working" if is_working_day else None
    if "holiday" in r:
        return "holiday"
    if "celebration" in r:
        return "celebration"
    if "assessment" in r or "assesment" in r:
        return "assessment"
    if "ptm" in r or "parent teacher" in r:
        return "ptm"
    if "event" in r:
        return "event"
    return "working" if is_working_day else "holiday"


# ---------------------------------------------------------------------------
# Parsing
# ---------------------------------------------------------------------------

@dataclass
class ParsedRow:
    date: date
    weekday: str
    sheet_day_number: Optional[int]
    label: str
    raw_category: str
    school_event: str
    document_numbers: str
    document_availability: str


def _locate_columns(rows: Sequence[Sequence[str]]) -> Optional[dict]:
    """Find the header row and map our field names to column indices."""
    for r_idx, row in enumerate(rows[:15]):
        norm_cells = [_norm(c) for c in row]
        if not any(c == "date" or c.endswith(" date") for c in norm_cells):
            continue
        col: dict = {"_header_row": r_idx}
        for field, keys in _HEADER_KEYS.items():
            for c_idx, cell in enumerate(norm_cells):
                if any(cell == k or cell.endswith(" " + k) for k in keys):
                    col.setdefault(field, c_idx)
        if "date" in col and "day_number" in col:
            return col
    return None


def parse_rows(rows: Sequence[Sequence[str]]) -> List[ParsedRow]:
    """Parse raw sheet rows into ``ParsedRow`` records (date-keyed, unordered)."""
    col = _locate_columns(rows)
    if col is None:
        raise SheetConfigError(
            "Could not find a calendar header row (needs 'Date' and 'Day #' columns)"
        )

    def cell(row: Sequence[str], field: str) -> str:
        idx = col.get(field)
        if idx is None or idx >= len(row):
            return ""
        return str(row[idx]).strip()

    out: List[ParsedRow] = []
    for row in rows[col["_header_row"] + 1:]:
        if not row:
            continue
        d = parse_sheet_date(cell(row, "date"))
        if d is None:
            continue
        out.append(
            ParsedRow(
                date=d,
                weekday=cell(row, "day") or d.strftime("%A"),
                sheet_day_number=parse_day_number(cell(row, "day_number")),
                label=cell(row, "description"),
                raw_category=cell(row, "category"),
                school_event=cell(row, "school_event"),
                document_numbers=cell(row, "doc_number"),
                document_availability=cell(row, "doc_availability"),
            )
        )
    return out


# ---------------------------------------------------------------------------
# Learning Day computation
# ---------------------------------------------------------------------------

@dataclass
class CalendarDay:
    academic_year_start: date
    date: date
    weekday: str
    is_working_day: bool
    learning_day: Optional[int]
    sheet_day_number: Optional[int]
    label: Optional[str]
    category: Optional[str]
    school_event: Optional[str]
    document_numbers: Optional[str]
    document_availability: Optional[str]

    def to_api(self) -> dict:
        return {
            "date": self.date.isoformat(),
            "weekday": self.weekday,
            "is_working_day": self.is_working_day,
            "learning_day": self.learning_day,
            "sheet_day_number": self.sheet_day_number,
            "label": self.label,
            "category": self.category,
            "school_event": self.school_event,
            "documents": self.document_numbers,
            "document_availability": self.document_availability,
        }


def compute_calendar_days(parsed: Iterable[ParsedRow]) -> List[CalendarDay]:
    """Assign a Learning Day number to every working day.

    * Rows are ordered by date; a later row for the same date wins (the sheet
      occasionally repeats a date).
    * ``is_working_day`` == the "Day #" cell held a number.
    * The counter is *anchored* to the sheet: the first working day of each
      academic year keeps the number the sheet gave it, then the counter
      increments by one on every subsequent working day and stays ``None`` on
      non-working days. So the sheet stays the source of truth for the starting
      number, but the school can create a mid-year holiday just by blanking one
      "Day #" cell — the following days renumber themselves.
    """
    by_date: dict[date, ParsedRow] = {}
    for row in parsed:
        by_date[row.date] = row

    counters: dict[date, int] = {}
    days: List[CalendarDay] = []
    for d in sorted(by_date):
        row = by_date[d]
        ay = academic_year_start_for(d)
        is_working = row.sheet_day_number is not None
        learning_day: Optional[int] = None
        if is_working:
            if ay not in counters:
                counters[ay] = row.sheet_day_number - 1  # anchor to the sheet
            counters[ay] += 1
            learning_day = counters[ay]
            if row.sheet_day_number != learning_day:
                logger.warning(
                    "School calendar: %s sheet Day # is %s but recomputed Learning "
                    "Day is %s (using recomputed).",
                    d.isoformat(), row.sheet_day_number, learning_day,
                )
        days.append(
            CalendarDay(
                academic_year_start=ay,
                date=d,
                weekday=row.weekday,
                is_working_day=is_working,
                learning_day=learning_day,
                sheet_day_number=row.sheet_day_number,
                label=row.label or None,
                category=normalize_category(row.raw_category, is_working),
                school_event=row.school_event or None,
                document_numbers=row.document_numbers or None,
                document_availability=row.document_availability or None,
            )
        )
    return days


def merge_branch_override(
    base_days: Sequence[CalendarDay], branch_days: Sequence[CalendarDay]
) -> List[CalendarDay]:
    """Overlay a branch-specific calendar on the school-wide one (by date).

    Learning Day numbers are recomputed across the merged set so a
    branch-specific holiday shifts that branch's numbering correctly.
    """
    merged: dict[date, ParsedRow] = {}
    for src in (base_days, branch_days):
        for cd in src:
            merged[cd.date] = ParsedRow(
                date=cd.date,
                weekday=cd.weekday,
                sheet_day_number=cd.sheet_day_number,
                label=cd.label or "",
                raw_category=cd.category or "",
                school_event=cd.school_event or "",
                document_numbers=cd.document_numbers or "",
                document_availability=cd.document_availability or "",
            )
    return compute_calendar_days(merged.values())


# ---------------------------------------------------------------------------
# IO: sync from Google + read from DB
# ---------------------------------------------------------------------------

_sync_lock = threading.Lock()
_last_sync_at: Optional[datetime] = None


def _branch_tab_map() -> dict:
    raw = (settings.school_calendar_branch_tabs or "").strip()
    if not raw:
        return {}
    try:
        m = json.loads(raw)
        return {str(k): str(v) for k, v in m.items()} if isinstance(m, dict) else {}
    except json.JSONDecodeError:
        logger.error("SCHOOL_CALENDAR_BRANCH_TABS is not valid JSON; ignoring.")
        return {}


def _upsert_scope(
    db: Session, branch_scope: str, days: Sequence[CalendarDay]
) -> dict:
    """Idempotently replace the rows for one branch scope. Portable (no ON CONFLICT)."""
    now = datetime.utcnow()
    wanted = {cd.date: cd for cd in days}
    ay_starts = {cd.academic_year_start for cd in days}

    existing = (
        db.query(SchoolCalendarDay)
        .filter(
            SchoolCalendarDay.branch_scope == branch_scope,
            SchoolCalendarDay.academic_year_start.in_(ay_starts),
        )
        .all()
        if ay_starts
        else []
    )
    existing_by_date = {r.calendar_date: r for r in existing}

    created = updated = deleted = 0
    for d, cd in wanted.items():
        row = existing_by_date.get(d)
        if row is None:
            row = SchoolCalendarDay(branch_scope=branch_scope, calendar_date=d)
            db.add(row)
            created += 1
        else:
            updated += 1
        row.academic_year_start = cd.academic_year_start
        row.weekday = cd.weekday
        row.is_working_day = cd.is_working_day
        row.learning_day = cd.learning_day
        row.sheet_day_number = cd.sheet_day_number
        row.label = cd.label
        row.category = cd.category
        row.school_event = cd.school_event
        row.document_numbers = cd.document_numbers
        row.document_availability = cd.document_availability
        row.synced_at = now

    for d, row in existing_by_date.items():
        if d not in wanted:
            db.delete(row)
            deleted += 1

    return {"created": created, "updated": updated, "deleted": deleted}


def sync(db: Session, *, force: bool = False) -> dict:
    """Pull the sheet and materialise it into ``school_calendar_day``.

    Returns a summary. Safe to call repeatedly — writes are upserts.
    """
    global _last_sync_at
    if not settings.google_sheets_spreadsheet_id:
        raise SheetConfigError("GOOGLE_SHEETS_SPREADSHEET_ID is not configured")

    with _sync_lock:
        base_rows = fetch_tab_rows(settings.school_calendar_base_tab)
        base_days = compute_calendar_days(parse_rows(base_rows))
        if not base_days:
            raise SheetConfigError("The calendar tab produced no dated rows")

        summary = {"scopes": {}, "academic_years": sorted(
            {cd.academic_year_start.isoformat() for cd in base_days}
        )}
        summary["scopes"][ALL_BRANCHES or "all"] = _upsert_scope(db, ALL_BRANCHES, base_days)

        for branch_id, tab_name in _branch_tab_map().items():
            try:
                branch_rows = fetch_tab_rows(tab_name)
                branch_days = merge_branch_override(
                    base_days, compute_calendar_days(parse_rows(branch_rows))
                )
                summary["scopes"][branch_id] = _upsert_scope(db, branch_id, branch_days)
            except Exception as e:  # noqa: BLE001 - one bad tab must not fail the rest
                logger.exception("Branch calendar tab '%s' failed: %s", tab_name, e)
                summary["scopes"][branch_id] = {"error": str(e)}

        db.commit()
        _last_sync_at = datetime.utcnow()
        summary["synced_at"] = _last_sync_at.isoformat()
        return summary


def _needs_sync(db: Session, ay_start: date, branch_scope: str) -> bool:
    newest = (
        db.query(SchoolCalendarDay.synced_at)
        .filter(
            SchoolCalendarDay.academic_year_start == ay_start,
            SchoolCalendarDay.branch_scope == branch_scope,
        )
        .order_by(SchoolCalendarDay.synced_at.desc())
        .first()
    )
    if newest is None or newest[0] is None:
        return True
    ttl = max(30, settings.school_calendar_cache_ttl_seconds)
    return datetime.utcnow() - newest[0] > timedelta(seconds=ttl)


def get_calendar(
    db: Session,
    academic_year_start: date,
    branch_id: Optional[str] = None,
    *,
    force_refresh: bool = False,
) -> List[dict]:
    """Return the calendar for a year/branch as a list of API dicts (date-ordered).

    Falls back to whatever is already stored if the sheet is unreachable.
    """
    branch_scope = branch_id or ALL_BRANCHES

    if force_refresh or _needs_sync(db, academic_year_start, branch_scope):
        try:
            sync(db, force=force_refresh)
        except Exception as e:  # noqa: BLE001 - serve stale data rather than 500
            logger.exception("School calendar sync failed; serving stored data: %s", e)

    rows = (
        db.query(SchoolCalendarDay)
        .filter(
            SchoolCalendarDay.academic_year_start == academic_year_start,
            SchoolCalendarDay.branch_scope.in_([branch_scope, ALL_BRANCHES]),
        )
        .all()
    )
    # Prefer a branch-specific row over the school-wide one for the same date.
    by_date: dict[date, SchoolCalendarDay] = {}
    for r in rows:
        cur = by_date.get(r.calendar_date)
        if cur is None or (r.branch_scope == branch_scope and cur.branch_scope != branch_scope):
            by_date[r.calendar_date] = r

    return [_row_to_api(by_date[d]) for d in sorted(by_date)]


def _row_to_api(r: SchoolCalendarDay) -> dict:
    return {
        "date": r.calendar_date.isoformat(),
        "weekday": r.weekday,
        "is_working_day": bool(r.is_working_day),
        "learning_day": r.learning_day,
        "sheet_day_number": r.sheet_day_number,
        "label": r.label,
        "category": r.category,
        "school_event": r.school_event,
        "documents": r.document_numbers,
        "document_availability": r.document_availability,
    }


def working_day_date_map(days: Sequence[dict]) -> dict:
    """learning_day -> date (ISO string) for the working days in a calendar."""
    return {d["learning_day"]: d["date"] for d in days if d.get("is_working_day")}


def remap_day_number(
    old_day: int,
    old_day_to_date: dict[int, date],
    date_to_new_day: dict[date, int],
) -> Optional[int]:
    """Re-map an existing content item's day number to the new sheet numbering.

    ``old_day_to_date`` comes from the *previous* calendar algorithm (which
    counted weekends). We look up the real calendar date that item was for,
    then read the new Learning Day number for that date. If that date is now a
    non-working day (e.g. it was a weekend), snap forward to the next working
    day so the content is never lost.
    """
    d = old_day_to_date.get(old_day)
    if d is None:
        return None
    if d in date_to_new_day:
        return date_to_new_day[d]
    for candidate in sorted(dt for dt in date_to_new_day if dt >= d):
        return date_to_new_day[candidate]
    return None
