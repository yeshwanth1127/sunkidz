
import os
os.chdir('/root/sunkidz/sunkidz/backend')
from app.core.database import SessionLocal
from app.models.user import User
from app.core.security import create_access_token
from datetime import timedelta

db = SessionLocal()
try:
    admin = db.query(User).filter(User.role == 'admin').first()
    if not admin:
        admin = db.query(User).first()
    if not admin:
        print('NO_ADMIN')
    else:
        token = create_access_token({'sub': str(admin.id), 'role': admin.role}, expires_delta=timedelta(minutes=60))
        print(token)
finally:
    db.close()
