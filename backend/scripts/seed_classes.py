"""Ensure classes exist for each branch based on its selected class system.
Run: python -m scripts.seed_classes
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.class_names import get_default_classes_for_system, normalize_class_name, normalize_system_type
from app.core.database import SessionLocal
from app.models.branch import Branch, BranchAssignment, Class

ACADEMIC_YEAR = "2026-27"


def seed():
    db = SessionLocal()
    try:
        # Create classes from selected system for each branch.
        branches = db.query(Branch).all()
        created = 0
        for branch in branches:
            system_type = normalize_system_type(getattr(branch, "system_type", None))
            for name in get_default_classes_for_system(system_type):
                canonical = normalize_class_name(name)
                existing = db.query(Class).filter(
                    Class.branch_id == branch.id,
                    Class.name == canonical,
                ).first()
                if not existing:
                    db.add(Class(
                        branch_id=branch.id,
                        name=canonical,
                        academic_year=ACADEMIC_YEAR,
                    ))
                    created += 1
                    print(f"Created {canonical} in {branch.name}")

        db.commit()

        # Reassign a teacher without class to the first Kreedo class when available.
        first_kreedo_class = db.query(Class).filter(Class.name == "1G1").first()
        if first_kreedo_class:
            unassigned = db.query(BranchAssignment).filter(
                BranchAssignment.branch_id == first_kreedo_class.branch_id,
                BranchAssignment.class_id.is_(None),
            ).first()
            if unassigned:
                unassigned.class_id = first_kreedo_class.id
                db.commit()
                print("Reassigned teacher to 1G1")

        print(f"Done. Created {created} classes.")

    finally:
        db.close()


if __name__ == "__main__":
    seed()
