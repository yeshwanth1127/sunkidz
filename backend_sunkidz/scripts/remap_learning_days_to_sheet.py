"""One-off: re-map existing Learning Module content to the Google-Sheet day numbers.

Before this feature, ``LearningVideo.school_day`` / ``DayFolder.school_day`` were
integer positions in a calendar that *counted weekends*. The sheet-driven
calendar skips weekends, so day N now falls on a different date.

This script pins every existing item to the **real calendar date** it was
uploaded for, then rewrites its day number to that date's new Learning Day
number (snapping weekend-dated items forward to the next working day).

Idempotent-ish: safe to re-run only if the calendar has not changed since the
last run. Take a DB backup first. Dry-run by default.

    python -m scripts.remap_learning_days_to_sheet          # dry run
    python -m scripts.remap_learning_days_to_sheet --apply  # write changes
"""
import sys
from datetime import date

from app.core.database import SessionLocal
from app.models import LearningVideo, DayFolder, SyllabusHoliday
from app.services.academic_calendar_service import (
    get_academic_year_for_date,
    get_school_days_with_dates,
)
from app.services import school_calendar_service


def _old_day_to_date(db, ay_start: date) -> dict[int, date]:
    start_year = ay_start.year
    holiday_dates = {
        r.holiday_date
        for r in db.query(SyllabusHoliday)
        .filter(
            SyllabusHoliday.academic_year_start == ay_start,
            SyllabusHoliday.branch_id.is_(None),
        )
        .all()
    }
    return {
        item["day"]: date.fromisoformat(item["date"])
        for item in get_school_days_with_dates(start_year, holiday_dates)
    }


def main(apply: bool) -> None:
    db = SessionLocal()
    try:
        try:
            school_calendar_service.sync(db, force=True)
        except Exception as e:  # noqa: BLE001
            print(f"ERROR: could not sync the Google Sheet calendar: {e}")
            print("Aborting — fix the sheet configuration and re-run.")
            sys.exit(1)

        ay_starts = sorted(
            {
                v.academic_year_start
                for v in db.query(LearningVideo.academic_year_start).distinct()
                if v.academic_year_start
            }
            | {
                f.academic_year_start
                for f in db.query(DayFolder.academic_year_start).distinct()
                if f.academic_year_start
            }
        )
        if not ay_starts:
            print("No existing learning content — nothing to remap.")
            return

        total = 0
        for ay_start in ay_starts:
            old_map = _old_day_to_date(db, ay_start)
            cal = school_calendar_service.get_calendar(db, ay_start, None)
            date_to_new = {
                date.fromisoformat(d["date"]): d["learning_day"]
                for d in cal
                if d["is_working_day"]
            }
            print(f"\n=== academic year starting {ay_start} ===")

            for model, label in ((LearningVideo, "video"), (DayFolder, "folder")):
                items = (
                    db.query(model)
                    .filter(
                        model.academic_year_start == ay_start,
                        model.school_day.isnot(None),
                    )
                    .all()
                )
                for it in items:
                    new_day = school_calendar_service.remap_day_number(
                        it.school_day, old_map, date_to_new
                    )
                    if new_day is None or new_day == it.school_day:
                        continue
                    print(f"  {label} {it.id}: day {it.school_day} -> {new_day}")
                    total += 1
                    if apply:
                        it.school_day = new_day

        if apply:
            db.commit()
            print(f"\nApplied {total} changes.")
        else:
            print(f"\nDry run: {total} items would change. Re-run with --apply.")
    finally:
        db.close()


if __name__ == "__main__":
    main(apply="--apply" in sys.argv)
