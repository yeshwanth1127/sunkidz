from pydantic import BaseModel
from typing import Any


class MarksCardUpsert(BaseModel):
    academic_year: str = "2026-27"
    data: dict[str, Any] = {}
