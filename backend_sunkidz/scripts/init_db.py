"""Create all database tables. Usage: python -m scripts.init_db
No alembic required - uses SQLAlchemy create_all.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.database import engine, Base
from app.models import User, Branch, Class, BranchAssignment, Student, ParentStudentLink, Enquiry

if __name__ == "__main__":
    print("Creating tables...")
    Base.metadata.create_all(bind=engine)
    print("Done.")
