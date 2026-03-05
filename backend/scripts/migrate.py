"""Run Alembic migrations. Usage: python -m scripts.migrate [alembic args...]
Examples:
  python -m scripts.migrate              # upgrade head
  python -m scripts.migrate upgrade head
  python -m scripts.migrate current
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from alembic.config import main as alembic_main

if __name__ == "__main__":
    argv = sys.argv[1:] if len(sys.argv) > 1 else ["upgrade", "head"]
    alembic_main(argv=argv)
