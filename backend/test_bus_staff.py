"""Test script to create and verify bus staff user"""
import sys
from sqlalchemy.orm import Session
from app.core.database import get_db, SessionLocal
from app.core.security import get_password_hash, verify_password
from app.models.user import User

def test_bus_staff():
    db = SessionLocal()
    try:
        # Check if bus staff user exists
        email = "busstaff@test.com"
        existing = db.query(User).filter(User.email == email).first()
        
        if existing:
            print(f"✓ User exists: {existing.email}")
            print(f"  Role: {existing.role}")
            print(f"  Name: {existing.full_name}")
            print(f"  Active: {existing.is_active}")
            print(f"  Has password: {'Yes' if existing.password_hash else 'No'}")
            
            # Test password
            test_password = "test123"
            if existing.password_hash:
                matches = verify_password(test_password, existing.password_hash)
                print(f"  Password 'test123' matches: {matches}")
        else:
            print("✗ No user found with email:", email)
            print("\nCreating test bus staff user...")
            
            new_user = User(
                email=email,
                password_hash=get_password_hash("test123"),
                full_name="Test Bus Staff",
                role="bus_staff",
                phone="1234567890",
                is_active="true"
            )
            db.add(new_user)
            db.commit()
            db.refresh(new_user)
            print(f"✓ Created user: {new_user.email} (ID: {new_user.id})")
            print(f"  Password: test123")
            
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    test_bus_staff()
