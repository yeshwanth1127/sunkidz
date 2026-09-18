"""Tests for the Google-Sheet-driven school calendar / Learning Day numbering.

Run:  python -m pytest tests/test_school_calendar.py -q   (from backend_sunkidz/)

Covers the eight required scenarios:
 1. normal Mon-Fri sequence          -> test_normal_weekday_sequence
 2. weekend skipping                 -> test_weekend_skipping
 3. holiday in the middle of a week  -> test_midweek_holiday
 4. multiple consecutive holidays    -> test_consecutive_holidays
 5. sheet update -> recalculation    -> test_sync_recalculates_on_change
 6. branch-specific calendar data    -> test_branch_override_renumbers
 7. existing uploads still map right -> test_remap_* / test_sync_remaps_existing_upload
 8. repeated refresh, no duplicates  -> test_sync_is_idempotent
"""
from datetime import date

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.services import school_calendar_service as scs
from app.services.school_calendar_service import (
    parse_sheet_date,
    parse_day_number,
    parse_rows,
    compute_calendar_days,
    merge_branch_override,
    normalize_category,
    remap_day_number,
)

HEADER = [
    "Date", "Day", "Day #", "Description",
    "Holiday / Celebration", "School Event",
    "Document Number", "Document Availability",
]


def rows(*data):
    return [HEADER, *[list(r) + [""] * (8 - len(r)) for r in data]]


# ---------------------------------------------------------------------------
# value parsing
# ---------------------------------------------------------------------------

def test_parse_sheet_date_formats():
    assert parse_sheet_date("2026-06-01") == date(2026, 6, 1)
    assert parse_sheet_date("2026-06-01 00:00:00") == date(2026, 6, 1)
    assert parse_sheet_date("1-Jun-26") == date(2026, 6, 1)
    assert parse_sheet_date("1-June-2026") == date(2026, 6, 1)
    assert parse_sheet_date("01/06/2026") == date(2026, 6, 1)
    assert parse_sheet_date("") is None
    assert parse_sheet_date("not a date") is None


def test_parse_day_number():
    assert parse_day_number("12") == 12
    assert parse_day_number("12.0") == 12
    assert parse_day_number("") is None
    assert parse_day_number("   ") is None
    # a plain number a spreadsheet mis-formatted as a date (Excel serial 102)
    assert parse_day_number("1900-04-11 00:00:00") == 102


def test_category_normalization():
    assert normalize_category("Holiday", False) == "holiday"
    assert normalize_category("Celebration", True) == "celebration"
    assert normalize_category("Assesment", True) == "assessment"
    assert normalize_category("PTM - Mun", True) == "ptm"
    assert normalize_category("", True) == "working"
    assert normalize_category("", False) is None


# ---------------------------------------------------------------------------
# 1. normal Mon-Fri sequence
# ---------------------------------------------------------------------------

def test_normal_weekday_sequence():
    r = rows(
        ("2026-06-01", "Monday", "1"),
        ("2026-06-02", "Tuesday", "2"),
        ("2026-06-03", "Wednesday", "3"),
        ("2026-06-04", "Thursday", "4"),
        ("2026-06-05", "Friday", "5"),
    )
    days = compute_calendar_days(parse_rows(r))
    assert [d.learning_day for d in days] == [1, 2, 3, 4, 5]
    assert all(d.is_working_day for d in days)
    assert all(d.academic_year_start == date(2026, 6, 1) for d in days)


# ---------------------------------------------------------------------------
# 2. weekend skipping
# ---------------------------------------------------------------------------

def test_weekend_skipping():
    r = rows(
        ("2026-06-05", "Friday", "5"),
        ("2026-06-06", "Saturday", ""),
        ("2026-06-07", "Sunday", ""),
        ("2026-06-08", "Monday", "6"),
    )
    days = {d.date: d for d in compute_calendar_days(parse_rows(r))}
    assert days[date(2026, 6, 6)].is_working_day is False
    assert days[date(2026, 6, 6)].learning_day is None
    assert days[date(2026, 6, 7)].learning_day is None
    assert days[date(2026, 6, 8)].learning_day == 6


def test_weekend_with_celebration_is_still_non_working():
    # Real sheet: "Parents Day" on a Saturday, blank Day # -> not a Learning Day.
    r = rows(
        ("2026-06-19", "Friday", "15"),
        ("2026-06-20", "Saturday", "", "Parents Day", "Celebration"),
        ("2026-06-22", "Monday", "16"),
    )
    days = {d.date: d for d in compute_calendar_days(parse_rows(r))}
    assert days[date(2026, 6, 20)].is_working_day is False
    assert days[date(2026, 6, 20)].learning_day is None
    assert days[date(2026, 6, 20)].category == "celebration"
    assert days[date(2026, 6, 22)].learning_day == 16


# ---------------------------------------------------------------------------
# 3. holiday in the middle of a week
# ---------------------------------------------------------------------------

def test_midweek_holiday():
    r = rows(
        ("2026-06-15", "Monday", "11"),
        ("2026-06-16", "Tuesday", "", "Some Holiday", "Holiday"),
        ("2026-06-17", "Wednesday", "12"),
        ("2026-06-18", "Thursday", "13"),
        ("2026-06-19", "Friday", "14"),
    )
    days = {d.date: d for d in compute_calendar_days(parse_rows(r))}
    assert days[date(2026, 6, 16)].learning_day is None
    assert days[date(2026, 6, 16)].category == "holiday"
    assert days[date(2026, 6, 17)].learning_day == 12
    assert days[date(2026, 6, 19)].learning_day == 14


# ---------------------------------------------------------------------------
# 4. multiple consecutive holidays
# ---------------------------------------------------------------------------

def test_consecutive_holidays():
    r = rows(
        ("2026-10-09", "Friday", "80"),
        ("2026-10-12", "Monday", "", "Navarathri", "Holiday"),
        ("2026-10-13", "Tuesday", "", "Navarathri", "Holiday"),
        ("2026-10-14", "Wednesday", "", "Navarathri", "Holiday"),
        ("2026-10-15", "Thursday", "", "Navarathri", "Holiday"),
        ("2026-10-16", "Friday", "", "Navarathri", "Holiday"),
        ("2026-10-19", "Monday", "81"),
    )
    days = {d.date: d for d in compute_calendar_days(parse_rows(r))}
    assert [days[date(2026, 10, d)].learning_day for d in (12, 13, 14, 15, 16)] == [None] * 5
    assert days[date(2026, 10, 9)].learning_day == 80
    assert days[date(2026, 10, 19)].learning_day == 81


# ---------------------------------------------------------------------------
# recompute wins over a stale "Day #" in the sheet
# ---------------------------------------------------------------------------

def test_recompute_overrides_stale_sheet_number():
    # School blanked Tuesday for a new holiday but forgot to renumber Wed/Thu.
    r = rows(
        ("2026-06-15", "Monday", "11"),
        ("2026-06-16", "Tuesday", "", "New Holiday", "Holiday"),
        ("2026-06-17", "Wednesday", "13"),   # stale — should become 12
        ("2026-06-18", "Thursday", "14"),    # stale — should become 13
    )
    days = {d.date: d for d in compute_calendar_days(parse_rows(r))}
    assert days[date(2026, 6, 17)].learning_day == 12
    assert days[date(2026, 6, 17)].sheet_day_number == 13
    assert days[date(2026, 6, 18)].learning_day == 13


def test_duplicate_date_row_last_wins():
    r = rows(
        ("2026-06-01", "Monday", "1"),
        ("2026-06-01", "Monday", "", "corrected to holiday", "Holiday"),
        ("2026-06-02", "Tuesday", "1"),
    )
    days = {d.date: d for d in compute_calendar_days(parse_rows(r))}
    assert days[date(2026, 6, 1)].is_working_day is False
    assert days[date(2026, 6, 2)].learning_day == 1


# ---------------------------------------------------------------------------
# 6. branch-specific calendar data
# ---------------------------------------------------------------------------

def test_branch_override_renumbers():
    base = compute_calendar_days(parse_rows(rows(
        ("2026-06-01", "Monday", "1"),
        ("2026-06-02", "Tuesday", "2"),
        ("2026-06-03", "Wednesday", "3"),
        ("2026-06-04", "Thursday", "4"),
    )))
    # This branch has a local holiday on the Tuesday.
    branch = compute_calendar_days(parse_rows(rows(
        ("2026-06-02", "Tuesday", "", "Branch founders day", "Holiday"),
    )))
    merged = {d.date: d for d in merge_branch_override(base, branch)}
    assert merged[date(2026, 6, 2)].is_working_day is False
    assert merged[date(2026, 6, 1)].learning_day == 1
    assert merged[date(2026, 6, 3)].learning_day == 2   # renumbered down
    assert merged[date(2026, 6, 4)].learning_day == 3


# ---------------------------------------------------------------------------
# 7. existing uploads still map to the right day (pure)
# ---------------------------------------------------------------------------

def test_remap_day_number_same_date():
    old = {12: date(2026, 6, 22)}
    new = {date(2026, 6, 22): 16}
    assert remap_day_number(12, old, new) == 16


def test_remap_day_number_snaps_weekend_forward():
    # Old numbering counted weekends: old day 12 landed on a Saturday.
    old = {12: date(2026, 6, 20)}                 # Saturday
    new = {date(2026, 6, 22): 16, date(2026, 6, 23): 17}
    assert remap_day_number(12, old, new) == 16   # snapped to Monday


def test_remap_day_number_unknown_old_day():
    assert remap_day_number(999, {1: date(2026, 6, 1)}, {date(2026, 6, 1): 1}) is None


# ---------------------------------------------------------------------------
# DB-backed: sync / idempotency / recalculation / stale fallback / remap
# ---------------------------------------------------------------------------

@pytest.fixture()
def db(tmp_path, monkeypatch):
    from app.models.school_calendar import SchoolCalendarDay
    from app.models.learning_module import LearningVideo, DayFolder

    engine = create_engine(
        f"sqlite:///{tmp_path/'t.db'}",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    for model in (SchoolCalendarDay, LearningVideo, DayFolder):
        model.__table__.create(engine)
    Session = sessionmaker(bind=engine)
    monkeypatch.setattr(scs.settings, "google_sheets_spreadsheet_id", "TEST_SHEET", raising=False)
    monkeypatch.setattr(scs.settings, "school_calendar_base_tab", "Base Document", raising=False)
    monkeypatch.setattr(scs.settings, "school_calendar_branch_tabs", "", raising=False)
    scs._last_sync_at = None
    s = Session()
    yield s
    s.close()


FIXTURE_A = rows(
    ("2026-06-01", "Monday", "1"),
    ("2026-06-02", "Tuesday", "2"),
    ("2026-06-03", "Wednesday", "3"),
    ("2026-06-04", "Thursday", "4"),
    ("2026-06-05", "Friday", "5"),
    ("2026-06-06", "Saturday", ""),
    ("2026-06-07", "Sunday", ""),
    ("2026-06-08", "Monday", "6"),
    ("2026-06-09", "Tuesday", "7"),
)

# Same period, but 2026-06-03 is now a holiday -> everything after shifts down 1.
FIXTURE_B = rows(
    ("2026-06-01", "Monday", "1"),
    ("2026-06-02", "Tuesday", "2"),
    ("2026-06-03", "Wednesday", "", "Surprise Holiday", "Holiday"),
    ("2026-06-04", "Thursday", "3"),
    ("2026-06-05", "Friday", "4"),
    ("2026-06-06", "Saturday", ""),
    ("2026-06-07", "Sunday", ""),
    ("2026-06-08", "Monday", "5"),
    ("2026-06-09", "Tuesday", "6"),
)


def test_sync_is_idempotent(db, monkeypatch):
    monkeypatch.setattr(scs, "fetch_tab_rows", lambda tab, spreadsheet_id=None: FIXTURE_A)

    scs.sync(db, force=True)
    first = scs.get_calendar(db, date(2026, 6, 1), None)
    scs.sync(db, force=True)
    scs.sync(db, force=True)
    second = scs.get_calendar(db, date(2026, 6, 1), None)

    from app.models.school_calendar import SchoolCalendarDay
    assert db.query(SchoolCalendarDay).count() == 9      # no duplicates
    assert first == second
    assert [d["learning_day"] for d in second] == [1, 2, 3, 4, 5, None, None, 6, 7]


def test_sync_recalculates_on_change(db, monkeypatch):
    holder = {"rows": FIXTURE_A}
    monkeypatch.setattr(scs, "fetch_tab_rows", lambda tab, spreadsheet_id=None: holder["rows"])

    scs.sync(db, force=True)
    before = {d["date"]: d["learning_day"] for d in scs.get_calendar(db, date(2026, 6, 1), None)}
    assert before["2026-06-08"] == 6

    holder["rows"] = FIXTURE_B
    scs.sync(db, force=True)
    after = {d["date"]: d["learning_day"] for d in scs.get_calendar(db, date(2026, 6, 1), None)}

    from app.models.school_calendar import SchoolCalendarDay
    assert db.query(SchoolCalendarDay).count() == 9      # still no duplicates
    assert after["2026-06-03"] is None                    # became a holiday
    assert after["2026-06-08"] == 5                       # shifted down by 1


def test_get_calendar_serves_stale_when_sheet_unreachable(db, monkeypatch):
    monkeypatch.setattr(scs, "fetch_tab_rows", lambda tab, spreadsheet_id=None: FIXTURE_A)
    scs.sync(db, force=True)

    def boom(*a, **k):
        raise RuntimeError("network down")

    monkeypatch.setattr(scs, "fetch_tab_rows", boom)
    days = scs.get_calendar(db, date(2026, 6, 1), None, force_refresh=True)
    assert [d["learning_day"] for d in days] == [1, 2, 3, 4, 5, None, None, 6, 7]


def test_sync_remaps_existing_upload(db, monkeypatch):
    """A video uploaded under the old numbering ends up on the same real date."""
    from app.models.learning_module import LearningVideo

    # Old calendar counted weekends: old "day 6" == 2026-06-06 (a Saturday).
    old_day_to_date = {
        1: date(2026, 6, 1), 2: date(2026, 6, 2), 3: date(2026, 6, 3),
        4: date(2026, 6, 4), 5: date(2026, 6, 5), 6: date(2026, 6, 6),
        7: date(2026, 6, 7), 8: date(2026, 6, 8),
    }
    vid = LearningVideo(
        module_id="m1", title="t", file_path="/x", file_name="x", file_size=10,
        school_day=8, academic_year_start=date(2026, 6, 1),
    )
    db.add(vid)
    db.commit()

    monkeypatch.setattr(scs, "fetch_tab_rows", lambda tab, spreadsheet_id=None: FIXTURE_A)
    scs.sync(db, force=True)
    cal = scs.get_calendar(db, date(2026, 6, 1), None)
    date_to_new = {date.fromisoformat(d["date"]): d["learning_day"]
                   for d in cal if d["is_working_day"]}

    new_day = scs.remap_day_number(8, old_day_to_date, date_to_new)
    assert new_day == 6            # old day 8 (2026-06-08) -> new Learning Day 6
    vid.school_day = new_day
    db.commit()
    assert db.query(LearningVideo).first().school_day == 6
