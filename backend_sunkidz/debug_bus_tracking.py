"""Debug script to link students to bus routes and verify bus tracking setup"""
import sys
from app.core.database import SessionLocal
from app.models.user import User
from app.models.student import Student, ParentStudentLink
from app.models.bus_route import BusRoute, RouteStudent

def debug_bus_tracking():
    db = SessionLocal()
    try:
        print("\n=== BUS TRACKING DEBUG ===\n")
        
        # 1. Check routes
        routes = db.query(BusRoute).all()
        print(f"📋 Routes: {len(routes)}")
        for route in routes:
            bus_staff = db.query(User).filter(User.id == route.bus_staff_id).first()
            print(f"  - {route.name} (ID: {route.id}, Staff: {bus_staff.full_name if bus_staff else 'N/A'})")
        
        # 2. Check students with bus opted
        students_opted = db.query(Student).filter(Student.bus_opted == True).all()
        print(f"\n👥 Students with bus_opted=true: {len(students_opted)}")
        for student in students_opted:
            parent_link = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student.id).first()
            parent_name = "No parent link"
            if parent_link:
                parent = db.query(User).filter(User.id == parent_link.user_id).first()
                parent_name = parent.full_name if parent else "N/A"
            print(f"  - {student.name} (ID: {student.id}, Parent: {parent_name})")
        
        # 3. Check if students are linked to routes
        if routes and students_opted:
            route = routes[0]
            route_students = db.query(RouteStudent).filter(RouteStudent.route_id == route.id).all()
            print(f"\n🚌 Students on route '{route.name}': {len(route_students)}")
            for rs in route_students:
                student = db.query(Student).filter(Student.id == rs.student_id).first()
                print(f"  - {student.name if student else 'Unknown'}")
            
            # Link opted students to first route if not already linked
            if len(route_students) < len(students_opted):
                print(f"\n🔗 Linking students to route '{route.name}'...")
                for student in students_opted:
                    existing = db.query(RouteStudent).filter(
                        RouteStudent.route_id == route.id,
                        RouteStudent.student_id == student.id
                    ).first()
                    if not existing:
                        rs = RouteStudent(route_id=route.id, student_id=student.id)
                        db.add(rs)
                        print(f"  ✓ Linked {student.name}")
                db.commit()
                print("✓ All students linked successfully")
        
        # 4. Verify parent can see rides
        parents = db.query(User).filter(User.role == "parent").all()
        print(f"\n👨‍👩‍👧 Parents: {len(parents)}")
        for parent in parents:
            links = db.query(ParentStudentLink).filter(ParentStudentLink.user_id == parent.id).all()
            print(f"  - {parent.full_name} ({parent.email}): {len(links)} students linked")
            for link in links:
                student = db.query(Student).filter(Student.id == link.student_id).first()
                if student:
                    print(f"    • {student.name} (bus_opted: {student.bus_opted})")
        
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    debug_bus_tracking()
