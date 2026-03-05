from pydantic import BaseModel
from typing import Any


class MarksCardUpsert(BaseModel):
    academic_year: str = "2024-25"
    data: dict[str, Any] = {}
