"""Check and clean up active rides"""
from app.core.database import SessionLocal
from app.models.ride_session import RideSession
from app.models.user import User

def check_active_rides():
    db = SessionLocal()
    try:
        # Get Umashankar user
        user = db.query(User).filter(User.email == "Umashankar@sunkidz.com").first()
        if not user:
            print("✗ User not found")
            return
        
        print(f"✓ User: {user.email} (ID: {user.id})")
        
        # Check for active rides
        active_rides = db.query(RideSession).filter(
            RideSession.bus_staff_id == user.id,
            RideSession.status == "active"
        ).all()
        
        if not active_rides:
            print("✓ No active rides found")
        else:
            print(f"\n⚠ Found {len(active_rides)} active ride(s):")
            for ride in active_rides:
                print(f"  - Ride ID: {ride.id}")
                print(f"    Route ID: {ride.route_id}")
                print(f"    Status: {ride.status}")
                print(f"    Start Time: {ride.start_time}")
                
            # Ask to clean up
            response = input("\nDelete all active rides? (yes/no): ")
            if response.lower() == 'yes':
                for ride in active_rides:
                    db.delete(ride)
                db.commit()
                print(f"✓ Deleted {len(active_rides)} active ride(s)")
            else:
                print("No changes made")
        
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    check_active_rides()
