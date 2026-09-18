"""Add sent_to_parent_at column to marks_cards if missing.
Run from backend dir: python scripts/add_marks_card_sent_column.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import text
from app.core.database import engine

def main():
    with engine.connect() as conn:
        try:
            conn.execute(text("ALTER TABLE marks_cards ADD COLUMN sent_to_parent_at TIMESTAMP WITH TIME ZONE"))
            conn.commit()
            print("Added sent_to_parent_at column")
        except Exception as e:
            err = str(e).lower()
            if "already exists" in err or "duplicate" in err:
                print("Column already exists")
            else:
                print(f"Error: {e}")

if __name__ == "__main__":
    main()
