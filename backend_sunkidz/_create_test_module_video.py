
import os
os.chdir('/root/sunkidz/sunkidz/backend')
from app.core.database import SessionLocal
from app.models.user import User
from app.models.learning_module import LearningModule, LearningVideo
from app.models import Class
from datetime import date

db = SessionLocal()
try:
    admin = db.query(User).filter(User.role == 'admin').first()
    if not admin:
        admin = db.query(User).first()
    if not admin:
        print('No user found to assign as created_by')
    name = 'E2E Test Module'
    module = db.query(LearningModule).filter(LearningModule.name == name).first()
    if not module:
        module = LearningModule(name=name, description='Test module created by automation', created_by=str(admin.id) if admin else '00000000-0000-0000-0000-000000000000')
        db.add(module)
        db.commit()
        db.refresh(module)
    # create learning video record
    v = LearningVideo(
        module_id=module.id,
        title='E2E Test Video',
        description='Uploaded by automation',
        file_path='/root/sunkidz/sunkidz/backend/uploads/learning-videos/test_video.mp4',
        file_name='test_video.mp4',
        file_size=0,
        duration=None,
        school_day=5,
        academic_year_start=date(2026,6,1),
    )
    db.add(v)
    db.commit()
    db.refresh(v)
    print('Created module', module.id)
    print('Created video', v.id)
    # choose a class id for calendar check
    cls = db.query(Class).first()
    if cls:
        print('First class id', cls.id)
    else:
        print('No class found')
finally:
    db.close()
