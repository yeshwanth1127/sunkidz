"""Add bus_opted column to students table.
Run from backend dir: python -m scripts.add_bus_opted_column"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import text
from app.core.database import engine

def main():
    with engine.connect() as conn:
        try:
            # Add the bus_opted column with default value False
            conn.execute(text("ALTER TABLE students ADD COLUMN bus_opted BOOLEAN DEFAULT FALSE"))
            conn.commit()
            print("✓ Added bus_opted column to students table")
        except Exception as e:
            err = str(e).lower()
            if "already exists" in err or "duplicate" in err:
                print("Column already exists")
            else:
                print(f"Error: {e}")
                raise

if __name__ == "__main__":
    main()
