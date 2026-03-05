"""Script to setup bus tracking - link opted students to routes"""
from app.core.database import SessionLocal
from app.models.user import User
from app.models.student import Student, ParentStudentLink
from app.models.bus_route import BusRoute, RouteStudent

def setup_bus_tracking():
    db = SessionLocal()
    try:
        print("\n=== SETTING UP BUS TRACKING ===\n")
        
        # Get first route
        route = db.query(BusRoute).first()
        if not route:
            print("✗ No bus route found. Run seed_bus_route.py first")
            return
        
        print(f"🚌 Using route: {route.name} (ID: {route.id})")
        
        # Get all students with bus_opted
        opted_students = db.query(Student).filter(Student.bus_opted == True).all()
        print(f"\n👥 Found {len(opted_students)} students with bus_opted=true")
        
        if not opted_students:
            print("\n⚠️  No students have bus_opted=true yet.")
            print("   Go to admin dashboard and toggle 'Opt Bus' on some students first.")
            return
        
        # Link them to route
        linked_count = 0
        for student in opted_students:
            # Check if already linked
            existing = db.query(RouteStudent).filter(
                RouteStudent.route_id == route.id,
                RouteStudent.student_id == student.id
            ).first()
            
            if not existing:
                rs = RouteStudent(route_id=route.id, student_id=student.id)
                db.add(rs)
                linked_count += 1
                print(f"  ✓ Linked: {student.name}")
            else:
                print(f"  → Already linked: {student.name}")
        
        if linked_count > 0:
            db.commit()
            print(f"\n✓ Linked {linked_count} students to route '{route.name}'")
        
        # Verify parents can see their children
        print(f"\n📋 Parent-Student Links:")
        parents = db.query(User).filter(User.role == "parent").all()
        for parent in parents:
            links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == parent.id).all()
            print(f"\n  Parent: {parent.full_name} ({parent.email})")
            print(f"  Students: {len(links)}")
            for link in links:
                student = db.query(Student).filter(Student.id == link.student_id).first()
                if student:
                    route_links = db.query(RouteStudent).filter(RouteStudent.student_id == student.id).all()
                    on_route = "✓" if route_links else "✗"
                    opted = "✓" if student.bus_opted else "✗"
                    print(f"    - {student.name} [bus_opted: {opted}] [on_route: {on_route}]")
        
        print("\n✅ Setup complete!")
        print("\nNext steps:")
        print("  1. Start a ride from bus staff dashboard")
        print("  2. Parent dashboard should show 'Bus In Transit'")
        
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    setup_bus_tracking()
