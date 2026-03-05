"""Debug script to verify bus route association"""
from app.core.database import SessionLocal
from app.models.user import User
from app.models.bus_route import BusRoute

def debug_route_association():
    db = SessionLocal()
    try:
        # Get test bus staff user
        bus_staff = db.query(User).filter(User.email == "busstaff@test.com").first()
        if not bus_staff:
            print("✗ Bus staff user not found")
            return
        
        print(f"✓ Bus staff user: {bus_staff.email}")
        print(f"  ID: {bus_staff.id}")
        print(f"  Role: {bus_staff.role}")
        print(f"  Active: {bus_staff.is_active}")
        
        # Check routes for this bus staff
        routes = db.query(BusRoute).filter(BusRoute.bus_staff_id == bus_staff.id).all()
        
        if not routes:
            print(f"\n✗ No routes found for bus staff {bus_staff.id}")
        else:
            print(f"\n✓ Found {len(routes)} route(s) for this bus staff:")
            for route in routes:
                print(f"  - {route.name} (ID: {route.id})")
                print(f"    Bus Staff ID: {route.bus_staff_id}")
                print(f"    Active: {route.is_active}")
                print(f"    Students: {len(route.students)}")
        
        # List all routes in the database
        print("\n--- All Routes in Database ---")
        all_routes = db.query(BusRoute).all()
        for route in all_routes:
            print(f"  - {route.name} (ID: {route.id})")
            print(f"    Bus Staff ID: {route.bus_staff_id}")
        
        if not all_routes:
            print("  (No routes found)")
            
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    debug_route_association()
