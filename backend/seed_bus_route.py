"""Script to create bus route for test bus staff"""
import sys
from uuid import UUID
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.user import User
from app.models.branch import Branch
from app.models.bus_route import BusRoute

def seed_bus_route():
    db = SessionLocal()
    try:
        # Get test bus staff user
        bus_staff = db.query(User).filter(User.email == "busstaff@test.com").first()
        if not bus_staff:
            print("✗ Bus staff user not found")
            return
        print(f"✓ Found bus staff: {bus_staff.email} (ID: {bus_staff.id})")
        
        # Check if bus staff already has a route
        existing_route = db.query(BusRoute).filter(BusRoute.bus_staff_id == bus_staff.id).first()
        if existing_route:
            print(f"✓ Bus staff already has route: {existing_route.name} (ID: {existing_route.id})")
            return
        
        # Get a branch (or create one)
        branch = db.query(Branch).first()
        if not branch:
            print("✗ No branch found in database")
            print("  Creating test branch...")
            branch = Branch(
                code="TEST",
                name="Test Branch",
                address="123 Test St",
                phone="9999999999",
            )
            db.add(branch)
            db.commit()
            db.refresh(branch)
            print(f"✓ Created branch: {branch.name} (ID: {branch.id})")
        else:
            print(f"✓ Using branch: {branch.name} (ID: {branch.id})")
        
        # Create bus route
        route = BusRoute(
            name="Morning Route",
            description="Test morning pickup route",
            shift="morning",
            branch_id=branch.id,
            bus_staff_id=bus_staff.id,
            is_active=True,
        )
        db.add(route)
        db.commit()
        db.refresh(route)
        print(f"✓ Created bus route: {route.name} (ID: {route.id})")
        print(f"  - Assigned to: {bus_staff.full_name}")
        print(f"  - Branch: {branch.name}")
        print(f"  - Shift: {route.shift}")
        
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    seed_bus_route()
