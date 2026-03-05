"""Check if student exists and test parent login.
Run from backend dir: python -m scripts.check_student_login"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import text
from app.core.database import engine
from app.models.student import Student, ParentStudentLink
from app.models.user import User
from sqlalchemy.orm import Session

def main():
    admission_number = "skzaec20260304"
    dob_str = "2020-03-14"  # Convert from 20200314 to YYYY-MM-DD format
    
    print(f"\n🔍 Checking for student: {admission_number}")
    print(f"   Date of Birth: {dob_str}")
    print("-" * 60)
    
    with Session(engine) as session:
        # Check if student exists
        student = session.query(Student).filter(
            Student.admission_number == admission_number
        ).first()
        
        if not student:
            print(f"❌ Student with admission_number '{admission_number}' NOT FOUND")
            print("\n📋 Listing all students:")
            all_students = session.query(Student).filter(
                Student.admission_number.isnot(None)
            ).limit(10).all()
            for s in all_students:
                print(f"   - {s.admission_number} | {s.name} | DOB: {s.date_of_birth}")
            return
        
        print(f"✅ Student FOUND:")
        print(f"   ID: {student.id}")
        print(f"   Name: {student.name}")
        print(f"   Admission Number: {student.admission_number}")
        print(f"   Date of Birth: {student.date_of_birth}")
        print(f"   Branch ID: {student.branch_id}")
        print(f"   Class ID: {student.class_id}")
        
        # Check if DOB matches
        from datetime import date
        try:
            dob = date.fromisoformat(dob_str)
            if student.date_of_birth == dob:
                print(f"✅ Date of Birth MATCHES")
            else:
                print(f"❌ Date of Birth DOES NOT MATCH")
                print(f"   Expected: {dob}")
                print(f"   Actual: {student.date_of_birth}")
        except ValueError as e:
            print(f"❌ Invalid date format: {e}")
        
        # Check parent link
        print(f"\n👨‍👩‍👧 Checking parent link...")
        parent_link = session.query(ParentStudentLink).filter(
            ParentStudentLink.student_id == student.id
        ).first()
        
        if not parent_link:
            print(f"❌ NO PARENT LINKED to this student")
            print(f"   Parent login will fail because no parent account is linked")
            return
        
        print(f"✅ Parent link FOUND:")
        print(f"   Link ID: {parent_link.id}")
        print(f"   User ID: {parent_link.user_id}")
        print(f"   Is Primary: {parent_link.is_primary}")
        
        # Get parent user details
        parent_user = session.query(User).filter(
            User.id == parent_link.user_id
        ).first()
        
        if parent_user:
            print(f"\n👤 Parent User Details:")
            print(f"   ID: {parent_user.id}")
            print(f"   Name: {parent_user.full_name}")
            print(f"   Email: {parent_user.email}")
            print(f"   Phone: {parent_user.phone}")
            print(f"   Role: {parent_user.role}")
            print(f"   Active: {parent_user.is_active}")
        else:
            print(f"❌ Parent user NOT FOUND")
            return
        
        # Print curl command
        print(f"\n🔧 CURL Command to test login:")
        print(f"\ncurl -X POST http://localhost:8000/api/auth/login \\")
        print(f'  -H "Content-Type: application/json" \\')
        print(f'  -d \'{{"admission_number": "{admission_number}", "date_of_birth": "{dob_str}"}}\'')
        
        print(f"\n📝 For PowerShell:")
        print(f'\n$body = @{{')
        print(f'    admission_number = "{admission_number}"')
        print(f'    date_of_birth = "{dob_str}"')
        print(f'}} | ConvertTo-Json')
        print(f'\nInvoke-RestMethod -Uri "http://localhost:8000/api/auth/login" -Method Post -Body $body -ContentType "application/json"')
        

if __name__ == "__main__":
    main()
