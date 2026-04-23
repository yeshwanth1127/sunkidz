"""Normalize class names to canonical display forms (IG-1, IG-2, IG-3)."""

from app.core.database import SessionLocal
from app.core.class_names import normalize_class_name
from app.models.branch import Class


def main() -> None:
    db = SessionLocal()
    try:
        classes = db.query(Class).all()
        changed = 0
        for cls in classes:
            normalized = normalize_class_name(cls.name)
            if normalized and normalized != cls.name:
                cls.name = normalized
                changed += 1
        db.commit()
        print(f"Normalized class names. Updated {changed} row(s).")
    finally:
        db.close()


if __name__ == "__main__":
    main()
