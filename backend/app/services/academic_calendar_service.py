"""Academic calendar: June 1 - March 31, 180 school days, with holiday support."""
from datetime import date, timedelta
from typing import Optional

# Academic year: June 1 (year Y) to March 31 (year Y+1)
# 180 school days = first 180 calendar days (incl. weekends) excluding admin-added holidays
# Holidays are added by admin; dates auto-update when holidays are marked


def get_academic_year_for_date(d: date) -> tuple[int, int]:
    """Return (start_year, end_year) e.g. (2024, 2025) for June 2024 - March 2025."""
    if d.month >= 6:
        return d.year, d.year + 1
    return d.year - 1, d.year


def get_academic_year_str(d: date) -> str:
    """Return e.g. '2024-25' for June 2024 - March 2025."""
    start, end = get_academic_year_for_date(d)
    return f"{start}-{str(end)[2:]}"


def academic_year_start(year: int) -> date:
    """June 1 of start year."""
    return date(year, 6, 1)


def academic_year_end(year: int) -> date:
    """March 31 of end year."""
    return date(year + 1, 3, 31)


def get_school_days_with_dates(
    start_year: int,
    holiday_dates: set[date],
) -> list[dict]:
    """
    Compute Day 1..180 -> date mapping.
    Returns list of {day: 1, date: "2024-06-01"}, ...
    Includes weekends. Only skips admin-added holidays.
    """
    start = academic_year_start(start_year)
    end = academic_year_end(start_year)
    result = []
    current = start
    day_num = 1
    while day_num <= 180 and current <= end:
        if current not in holiday_dates:
            result.append({
                "day": day_num,
                "date": current.isoformat(),
            })
            day_num += 1
        current += timedelta(days=1)
    return result


def get_date_for_school_day(
    start_year: int,
    school_day: int,
    holiday_dates: set[date],
) -> Optional[date]:
    """Get the calendar date for a given school day (1-180)."""
    mapping = get_school_days_with_dates(start_year, holiday_dates)
    for item in mapping:
        if item["day"] == school_day:
            return date.fromisoformat(item["date"])
    return None


def get_school_day_for_date(
    start_year: int,
    d: date,
    holiday_dates: set[date],
) -> Optional[int]:
    """Get school day number (1-180) for a given date, or None if holiday."""
    if d in holiday_dates:
        return None
    mapping = get_school_days_with_dates(start_year, holiday_dates)
    for item in mapping:
        if date.fromisoformat(item["date"]) == d:
            return item["day"]
    return None
