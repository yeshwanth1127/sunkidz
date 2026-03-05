"""Create classes: playgroup, ig1, ig2, ig3. Remove Nursery A.
Run: python -m scripts.seed_classes
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings
from app.core.database import SessionLocal
from app.models.branch import Branch, BranchAssignment, Class

ACADEMIC_YEAR = "2024-25"


def seed():
    db = SessionLocal()
    try:
        # Delete Nursery A (and any nursery classes)
        nursery_classes = db.query(Class).filter(Class.name.ilike("%nursery%")).all()
        for cls in nursery_classes:
            db.delete(cls)
        db.commit()
        if nursery_classes:
            print(f"Removed {len(nursery_classes)} nursery class(es)")

        # Create playgroup, ig1, ig2, ig3 for each branch
        branches = db.query(Branch).all()
        created = 0
        for branch in branches:
            for name in settings.default_branch_classes:
                existing = db.query(Class).filter(
                    Class.branch_id == branch.id,
                    Class.name == name,
                ).first()
                if not existing:
                    db.add(Class(
                        branch_id=branch.id,
                        name=name,
                        academic_year=ACADEMIC_YEAR,
                    ))
                    created += 1
                    print(f"Created {name} in {branch.name}")

        db.commit()

        # Reassign teacher (who had class_id) to ig1
        ig1 = db.query(Class).filter(Class.name == "ig1").first()
        if ig1:
            unassigned = db.query(BranchAssignment).filter(
                BranchAssignment.branch_id == ig1.branch_id,
                BranchAssignment.class_id.is_(None),
            ).first()
            if unassigned:
                unassigned.class_id = ig1.id
                db.commit()
                print("Reassigned teacher to ig1")

        print(f"Done. Created {created} classes.")

    finally:
        db.close()


if __name__ == "__main__":
    seed()
