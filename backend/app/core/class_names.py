import re

KREEDO_SYSTEM = "kreedo"
NORMAL_SYSTEM = "normal"

CLASS_SYSTEM_DEFAULTS: dict[str, tuple[str, ...]] = {
    KREEDO_SYSTEM: ("Playschool", "1G1", "1G2", "1G3"),
    NORMAL_SYSTEM: ("Nursery", "LKG", "UKG"),
}


def normalize_system_type(system_type: str | None) -> str:
    text = (system_type or "").strip().lower()
    if text in CLASS_SYSTEM_DEFAULTS:
        return text
    return KREEDO_SYSTEM


def get_default_classes_for_system(system_type: str | None) -> tuple[str, ...]:
    normalized = normalize_system_type(system_type)
    return CLASS_SYSTEM_DEFAULTS[normalized]


def normalize_class_name(name: str | None) -> str:
    text = (name or "").strip()
    if not text:
        return ""

    compact = re.sub(r"\s+", "", text).lower()
    mapping = {
        "playschool": "Playschool",
        "playgroup": "Playschool",
        "1g1": "1G1",
        "ig1": "1G1",
        "ig-1": "1G1",
        "1g2": "1G2",
        "ig2": "1G2",
        "ig-2": "1G2",
        "1g3": "1G3",
        "ig3": "1G3",
        "ig-3": "1G3",
        "nursery": "Nursery",
        "lkg": "LKG",
        "ukg": "UKG",
    }
    return mapping.get(compact, text)
