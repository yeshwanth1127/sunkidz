"""Add father, mother, guardian, emergency contact, religion, transport to students.
Run: python -m scripts.add_student_admission_fields"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import text
from app.core.database import engine

COLS = [
    ("religion", "VARCHAR(100)"),
    ("father_name", "VARCHAR(255)"),
    ("father_occupation", "VARCHAR(255)"),
    ("father_contact_no", "VARCHAR(50)"),
    ("father_email", "VARCHAR(255)"),
    ("mother_name", "VARCHAR(255)"),
    ("mother_occupation", "VARCHAR(255)"),
    ("mother_contact_no", "VARCHAR(50)"),
    ("mother_email", "VARCHAR(255)"),
    ("guardian_name", "VARCHAR(255)"),
    ("guardian_relation", "VARCHAR(100)"),
    ("guardian_contact_no", "VARCHAR(50)"),
    ("emergency_contact_name", "VARCHAR(255)"),
    ("emergency_contact_phone", "VARCHAR(50)"),
    ("transport_required", "BOOLEAN"),
]

def run():
    with engine.connect() as conn:
        for col, typ in COLS:
            try:
                conn.execute(text(f"ALTER TABLE students ADD COLUMN IF NOT EXISTS {col} {typ}"))
            except Exception as e:
                if "already exists" not in str(e).lower():
                    print(f"Skip {col}: {e}")
        conn.commit()
    print("Student admission fields added.")

if __name__ == "__main__":
    run()
