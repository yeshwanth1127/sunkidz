"""Seed admin user. Run: python -m scripts.seed_admin"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings
from app.core.database import SessionLocal
from app.core.security import get_password_hash
from app.models.user import User
from app.models.branch import Branch, BranchAssignment, Class


def seed():
    db = SessionLocal()
    try:
        if db.query(User).filter(User.email == "admin@sunkidz.com").first():
            print("Admin user already exists")
            return
        admin = User(
            email="admin@sunkidz.com",
            password_hash=get_password_hash("principal_admin@123!"),
            full_name="Admin",
            role="admin",
            is_active="true",
        )
        db.add(admin)
        db.commit()
        db.refresh(admin)
        print(f"Created admin user: {admin.email} (password: principal_admin@123!)")

        # Create a sample branch and class
        branch = db.query(Branch).first()
        if not branch:
            branch = Branch(
                name="Main Branch",
                code="main",
                address="123 Main St",
                contact_no="+1234567890",
                status="active",
            )
            db.add(branch)
            db.commit()
            db.refresh(branch)
            print(f"Created branch: {branch.name}")

        # Ensure default classes for this branch
        for class_name in settings.default_branch_classes:
            if not db.query(Class).filter(Class.branch_id == branch.id, Class.name == class_name).first():
                db.add(Class(branch_id=branch.id, name=class_name, academic_year="2024-25"))
        db.commit()
        cls = db.query(Class).filter(Class.branch_id == branch.id, Class.name == "ig1").first()

        # Create coordinator and teacher for demo
        coord = db.query(User).filter(User.email == "coord@sunkidz.com").first()
        if not coord:
            coord = User(
                email="coord@sunkidz.com",
                password_hash=get_password_hash("coord123"),
                full_name="Sarah Coordinator",
                role="coordinator",
                is_active="true",
            )
            db.add(coord)
            db.commit()
            db.refresh(coord)
            db.add(BranchAssignment(user_id=coord.id, branch_id=branch.id))
            db.commit()
            print(f"Created coordinator: {coord.email} (password: coord123)")

        teacher = db.query(User).filter(User.email == "teacher@sunkidz.com").first()
        if not teacher:
            teacher = User(
                email="teacher@sunkidz.com",
                password_hash=get_password_hash("teacher123"),
                full_name="Jane Teacher",
                role="teacher",
                is_active="true",
            )
            db.add(teacher)
            db.commit()
            db.refresh(teacher)
            db.add(BranchAssignment(user_id=teacher.id, branch_id=branch.id, class_id=cls.id))
            db.commit()
            print(f"Created teacher: {teacher.email} (password: teacher123)")

    finally:
        db.close()


if __name__ == "__main__":
    seed()
