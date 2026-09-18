import re

SUNKIDZ_SYSTEM = "sunkidz"
LEGACY_KREEDO_SYSTEM = "kreedo"
NORMAL_SYSTEM = "normal"

# SunKidz uses a single standard grade structure regardless of a branch's
# stored system_type: Playgroup, IG1, IG2, IG3 -- always in this exact
# order. Nursery/LKG/UKG are legacy names from an older naming scheme and
# are no longer valid canonical classes -- they are not generated, not
# accepted as aliases, and not mapped to anything here. "Playschool" is
# also a retired spelling of the same level; it is normalized to
# "Playgroup" but never produced as a canonical value.
STANDARD_CLASSES: tuple[str, ...] = ("Playgroup", "IG1", "IG2", "IG3")

# Fixed display/sort order -- never alphabetical, never insertion order.
GRADE_ORDER: dict[str, int] = {name: i for i, name in enumerate(STANDARD_CLASSES)}

CLASS_SYSTEM_DEFAULTS: dict[str, tuple[str, ...]] = {
    SUNKIDZ_SYSTEM: STANDARD_CLASSES,
    NORMAL_SYSTEM: STANDARD_CLASSES,
}

# Legacy class names that must no longer be accepted anywhere a class name
# is created or renamed. Matched after the same whitespace/dash-insensitive,
# lowercased normalization used by normalize_class_name.
LEGACY_CLASS_NAMES: frozenset[str] = frozenset({"nursery", "lkg", "ukg"})


def normalize_system_type(system_type: str | None) -> str:
    text = (system_type or "").strip().lower()
    if text == LEGACY_KREEDO_SYSTEM:
        return SUNKIDZ_SYSTEM
    if text in CLASS_SYSTEM_DEFAULTS:
        return text
    return SUNKIDZ_SYSTEM


def get_default_classes_for_system(system_type: str | None) -> tuple[str, ...]:
    normalized = normalize_system_type(system_type)
    return CLASS_SYSTEM_DEFAULTS[normalized]


def normalize_class_name(name: str | None) -> str:
    text = (name or "").strip()
    if not text:
        return ""

    compact = re.sub(r"\s+", "", text).lower()
    mapping = {
        "playgroup": "Playgroup",
        "playschool": "Playgroup",
        "ig1": "IG1",
        "1g1": "IG1",
        "ig-1": "IG1",
        "ig2": "IG2",
        "1g2": "IG2",
        "ig-2": "IG2",
        "ig3": "IG3",
        "1g3": "IG3",
        "ig-3": "IG3",
    }
    return mapping.get(compact, text)


def grade_sort_key(name: str | None) -> tuple[int, str]:
    """Sort key enforcing the fixed Playgroup -> IG1 -> IG2 -> IG3 order.
    Never alphabetical, never database/API insertion order. Names outside
    the standard 4 (e.g. a custom class) sort after them, alphabetically
    among themselves as a stable tiebreaker."""
    canon = normalize_class_name(name)
    return (GRADE_ORDER.get(canon, len(GRADE_ORDER)), canon)


def is_legacy_class_name(name: str | None) -> bool:
    """True if `name` is one of the retired Nursery/LKG/UKG names (in any
    spacing/casing/dash variant). Callers that create or rename classes
    should reject these rather than accept or normalize them."""
    text = (name or "").strip()
    if not text:
        return False
    key = re.sub(r"[\s_-]+", "", text).lower()
    return key in LEGACY_CLASS_NAMES
