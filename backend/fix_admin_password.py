#!/usr/bin/env python3
"""Fix admin user password hash."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import get_password_hash, verify_password

db = SessionLocal()
try:
    u = db.query(User).filter(User.email == "admin@sunkidz.com").first()
    if u:
        new_hash = get_password_hash("admin123")
        print(f"Old hash: {u.password_hash}")
        print(f"New hash: {new_hash}")
        u.password_hash = new_hash
        db.commit()
        print("✅ Hash updated")
        
        # Verify it works
        u = db.query(User).filter(User.email == "admin@sunkidz.com").first()
        check = verify_password("admin123", u.password_hash)
        print(f"Verification test: {check}")
    else:
        print("Admin user not found")
finally:
    db.close()
