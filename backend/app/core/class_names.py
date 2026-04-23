import re


def normalize_class_name(name: str | None) -> str:
    text = (name or "").strip()
    if not text:
        return ""

    compact = re.sub(r"\s+", "", text).lower()
    mapping = {
        "ig1": "IG-1",
        "ig-1": "IG-1",
        "ig2": "IG-2",
        "ig-2": "IG-2",
        "ig3": "IG-3",
        "ig-3": "IG-3",
    }
    return mapping.get(compact, text)
