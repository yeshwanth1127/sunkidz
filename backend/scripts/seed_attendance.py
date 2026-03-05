#!/usr/bin/env python3
"""Seed attendance data for testing."""
from datetime import datetime, timedelta
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from sqlalchemy.orm import Session
from app.core.database import SessionLocal, engine, Base
from app.models import Student, Attendance, User

def seed_attendance():
    """Seed attendance data for all students for the last 30 days."""
    db: Session = SessionLocal()
    
    try:
        # Get all students
        students = db.query(Student).all()
        
        if not students:
            print("❌ No students found. Please create students first.")
            return
        
        print(f"📚 Found {len(students)} students")
        
        # Get a teacher user to mark attendance
        teacher = db.query(User).filter(User.role == "teacher").first()
        if not teacher:
            print("⚠️ No teacher found for marking attendance. Will mark as None.")
        
        # Create attendance records for the last 30 days
        today = datetime.now().date()
        for i in range(30):
            date = today - timedelta(days=i)
            
            # Skip weekends (Saturday=5, Sunday=6)
            if date.weekday() >= 5:
                continue
            
            for student in students:
                # Check if attendance already exists
                existing = db.query(Attendance).filter(
                    Attendance.student_id == student.id,
                    Attendance.date == date
                ).first()
                
                if existing:
                    continue
                
                # Randomly assign status: 70% present, 20% absent, 10% leave
                import random
                rand = random.random()
                if rand < 0.7:
                    status = "present"
                elif rand < 0.9:
                    status = "absent"
                else:
                    status = "leave"
                
                attendance = Attendance(
                    student_id=student.id,
                    date=date,
                    status=status,
                    marked_by=teacher.id if teacher else None,
                )
                db.add(attendance)
                
                print(f"✅ Added {status} attendance for {student.name} on {date}")
        
        db.commit()
        print(f"\n✅ Attendance data seeded successfully!")
        
    except Exception as e:
        print(f"❌ Error seeding attendance: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_attendance()
