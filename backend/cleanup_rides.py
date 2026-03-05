"""Clean up active rides"""
from app.core.database import SessionLocal
from app.models.ride_session import RideSession
from app.models.user import User
from datetime import datetime, timezone

def cleanup_active_rides():
    db = SessionLocal()
    try:
        # Get all active rides
        active_rides = db.query(RideSession).filter(RideSession.status == "active").all()
        
        if not active_rides:
            print("✅ No active rides to clean up")
            return
        
        print(f"\n⚠️  Found {len(active_rides)} active ride(s):\n")
        for ride in active_rides:
            user = db.query(User).filter(User.id == ride.bus_staff_id).first()
            duration = datetime.now(timezone.utc) - ride.start_time
            print(f"  Ride ID: {ride.id}")
            print(f"  Bus Staff: {user.full_name if user else 'Unknown'} ({user.email if user else 'N/A'})")
            print(f"  Started: {ride.start_time} ({duration.total_seconds() / 60:.1f} minutes ago)")
            print(f"  Route ID: {ride.route_id}")
            print()
        
        choice = input("Delete all active rides? (y/n): ")
        if choice.lower() == 'y':
            for ride in active_rides:
                db.delete(ride)
            db.commit()
            print(f"\n✅ Deleted {len(active_rides)} active ride(s)")
        else:
            print("\n❌ Cleanup cancelled")
        
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    cleanup_active_rides()
