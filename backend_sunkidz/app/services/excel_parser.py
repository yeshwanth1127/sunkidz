"""Parse a school timetable Excel file and extract grade + timing slots.

Expected Excel format (.xlsx):
  - Sheet name OR a cell in the first 5 rows contains the grade/class name
    e.g. sheet named "Grade 3A", or a cell saying "Grade: 3A" / "Class: KG-B"
  - Rows with a time-like value in the first or second column are treated as slots:
      | 8:00 AM - 9:00 AM | Morning Assembly |
      | 9:00 - 10:00       | English          |
  - Any row whose first non-empty cell does NOT look like a time is skipped
    (headers, blank rows, grade label rows, etc.)

Returns:
  {
    "detected_grade": str | None,   # raw text found in the file
    "slots": [
      {"timing": str, "description": str | None, "slot_order": int},
      ...
    ]
  }
"""

import io
import re
from typing import Optional

import openpyxl

# Matches patterns like "8:00", "08:30 AM", "8.00", "8h00"
_TIME_RE = re.compile(r"\b\d{1,2}[:.h]\d{2}\b", re.IGNORECASE)

# Keywords that signal a grade/class label cell
_GRADE_KEYWORDS = re.compile(
    r"\b(grade|class|std|standard|section|kg|lkg|ukg|nursery|pre[-\s]?k)\b",
    re.IGNORECASE,
)


def _cell_str(cell) -> str:
    """Return a stripped string value for a cell, empty string if None."""
    if cell is None or cell.value is None:
        return ""
    return str(cell.value).strip()


def _looks_like_timing(text: str) -> bool:
    """True if the text contains at least one time-like token."""
    return bool(_TIME_RE.search(text))


def _extract_grade_from_cell(text: str) -> Optional[str]:
    """
    If the cell contains a grade keyword, return the whole cell value as the
    grade name (stripped). Otherwise return None.
    """
    if not text:
        return None
    if _GRADE_KEYWORDS.search(text):
        # Strip common label prefixes like "Grade:" or "Class:"
        cleaned = re.sub(r"^(grade|class|std|standard)\s*[:\-–]?\s*", "", text, flags=re.IGNORECASE).strip()
        return cleaned or text
    return None


def parse_timetable_excel(file_bytes: bytes) -> dict:
    """
    Parse a .xlsx file from raw bytes.
    Returns {"detected_grade": str|None, "slots": list[dict]}.
    Raises ValueError on unreadable or empty files.
    """
    try:
        wb = openpyxl.load_workbook(io.BytesIO(file_bytes), data_only=True)
    except Exception as exc:
        raise ValueError(f"Could not open Excel file: {exc}")

    ws = wb.active  # Use the first / active sheet

    # --- Attempt 1: grade from sheet name ---
    detected_grade: Optional[str] = None
    sheet_name = ws.title or ""
    if _GRADE_KEYWORDS.search(sheet_name):
        detected_grade = sheet_name.strip()

    slots = []
    slot_order = 0

    for row in ws.iter_rows():
        # Collect non-empty cell values in order
        cells = [_cell_str(c) for c in row]
        non_empty = [c for c in cells if c]

        if not non_empty:
            continue  # blank row

        first = non_empty[0]

        # --- Attempt 2: grade from cell content (scan first 5 rows) ---
        if slot_order == 0 and detected_grade is None:
            for cell_val in non_empty:
                g = _extract_grade_from_cell(cell_val)
                if g:
                    detected_grade = g
                    break
            # If this row was only a grade label, skip to next row
            if detected_grade and not _looks_like_timing(first):
                continue

        # --- Timing row detection ---
        if not _looks_like_timing(first):
            # Maybe timing is in the second cell
            if len(non_empty) >= 2 and _looks_like_timing(non_empty[1]):
                timing = non_empty[1]
                description = non_empty[2] if len(non_empty) > 2 else None
            else:
                continue  # header or label row — skip
        else:
            timing = first
            # Description is everything after the timing cell, joined
            rest = non_empty[1:]
            description = " | ".join(rest) if rest else None

        # Clean up empty descriptions
        if description and not description.strip():
            description = None

        slots.append({
            "timing": timing,
            "description": description,
            "slot_order": slot_order,
        })
        slot_order += 1

    if not slots:
        raise ValueError(
            "No timing rows found in the Excel file. "
            "Ensure each row has a time value in the first column "
            "(e.g. '8:00 AM – 9:00 AM')."
        )

    return {"detected_grade": detected_grade, "slots": slots}
