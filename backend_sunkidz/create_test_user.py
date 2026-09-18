#!/usr/bin/env python3
"""Create a test teacher user for Google Play Store review."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import get_password_hash, verify_password

TEST_EMAIL = "testuser@sunkidz.com"
TEST_PASSWORD = "TestPassword123"
TEST_ROLE = "teacher"  # Teacher role gives reviewers a clear, feature-rich view

db = SessionLocal()
try:
    existing = db.query(User).filter(User.email == TEST_EMAIL).first()
    if existing:
        print(f"⚠️  User '{TEST_EMAIL}' already exists. Updating password...")
        existing.password_hash = get_password_hash(TEST_PASSWORD)
        existing.is_active = "true"
        db.commit()
        print(f"✅ Password updated for '{TEST_EMAIL}'")
    else:
        new_user = User(
            email=TEST_EMAIL,
            full_name="Google Play Reviewer",
            phone="9999999999",
            role=TEST_ROLE,
            password_hash=get_password_hash(TEST_PASSWORD),
            is_active="true",
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        print(f"✅ Test user created successfully!")
        print(f"   ID:       {new_user.id}")
        print(f"   Email:    {TEST_EMAIL}")
        print(f"   Password: {TEST_PASSWORD}")
        print(f"   Role:     {TEST_ROLE}")

    # Verify login works
    user = db.query(User).filter(User.email == TEST_EMAIL).first()
    ok = verify_password(TEST_PASSWORD, user.password_hash)
    print(f"\n🔐 Login verification: {'✅ PASS' if ok else '❌ FAIL'}")

finally:
    db.close()
