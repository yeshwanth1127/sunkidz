"""
Initialize database with bus tracking tables.
Run: python -m scripts.init_bus_tracking
"""
import sys
from app.core.database import engine, Base
from app.models import (
    BusRoute, RouteStudent, RideSession, LocationUpdate
)

def init_db():
    """Create all tables."""
    print("Creating bus tracking tables...")
    Base.metadata.create_all(bind=engine)
    print("✓ Bus tracking tables created successfully!")

if __name__ == "__main__":
    try:
        init_db()
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
