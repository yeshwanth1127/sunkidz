"""Normalize class names to canonical display forms (Playschool, 1G1, 1G2, 1G3, Nursery, LKG, UKG)."""

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
