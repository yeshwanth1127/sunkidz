"""Update bus route to assign to the correct user"""
from uuid import UUID
from app.core.database import SessionLocal
from app.models.user import User
from app.models.bus_route import BusRoute

def reassign_route():
    db = SessionLocal()
    try:
        # Find the actual logged-in bus staff
        umashankar = db.query(User).filter(User.email == "Umashankar@sunkidz.com").first()
        if not umashankar:
            print("✗ Umashankar user not found")
            return
        
        print(f"✓ Found user: {umashankar.email} (ID: {umashankar.id})")
        print(f"  Role: {umashankar.role}")
        
        # Get the existing route
        route = db.query(BusRoute).filter(BusRoute.name == "Morning Route").first()
        if not route:
            print("✗ Morning Route not found")
            return
        
        print(f"✓ Found route: {route.name} (ID: {route.id})")
        print(f"  Current bus_staff_id: {route.bus_staff_id}")
        
        # Reassign the route
        route.bus_staff_id = umashankar.id
        db.commit()
        db.refresh(route)
        
        print(f"\n✓ Route reassigned!")
        print(f"  New bus_staff_id: {route.bus_staff_id}")
        print(f"  Bus staff: {umashankar.full_name} ({umashankar.email})")
        
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    reassign_route()
