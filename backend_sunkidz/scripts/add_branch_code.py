"""Add branch code column. Run: python -m scripts.add_branch_code"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import text
from app.core.database import engine, SessionLocal
from app.models.branch import Branch

def run():
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE branches ADD COLUMN IF NOT EXISTS code VARCHAR(20)"))
            conn.commit()
        except Exception as e:
            if "already exists" not in str(e).lower():
                raise
    db = SessionLocal()
    try:
        for b in db.query(Branch).all():
            if not b.code:
                b.code = "main" if (b.name and "main" in b.name.lower()) else (b.name or "main")[:3].lower().replace(" ", "")
        db.commit()
        print("Branch codes updated.")
    finally:
        db.close()

if __name__ == "__main__":
    run()
