import logging
from logging.handlers import RotatingFileHandler
from uuid import UUID
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from app.core.database import engine, Base, get_db
from app.core.auth import require_admin
from app.models import User, Branch, Class, BranchAssignment, Student, ParentStudentLink, Enquiry
from app.api import auth as auth_api
from app.api import me as me_api
from app.api import admin as admin_api
from app.api import enquiry as enquiry_api
from app.api import admission as admission_api
from app.api import marks as marks_api
from app.api import teacher as teacher_api
from app.api import coordinator as coordinator_api
from app.api import parent as parent_api
from app.api import bus_tracking as bus_tracking_api
from app.api import syllabus as syllabus_api

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        RotatingFileHandler('app.log', maxBytes=10485760, backupCount=5),
        logging.StreamHandler()
    ]
)

app = FastAPI(
    title="Preschool LMS API",
    version="1.0.0",
    docs_url="/docs",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_api.router, prefix="/api/v1")
app.include_router(me_api.router, prefix="/api/v1")
app.include_router(admission_api.router, prefix="/api/v1")
app.include_router(admin_api.router, prefix="/api/v1")
app.include_router(enquiry_api.router, prefix="/api/v1")
app.include_router(marks_api.router, prefix="/api/v1")
app.include_router(teacher_api.router, prefix="/api/v1")
app.include_router(coordinator_api.router, prefix="/api/v1")
app.include_router(parent_api.router, prefix="/api/v1")
app.include_router(bus_tracking_api.router, prefix="/api/v1")
app.include_router(syllabus_api.router, prefix="/api/v1")


@app.get("/")
def root():
    return {"message": "Sunkidz LMS API", "docs": "/docs", "health": "/health"}


@app.get("/health")
def health():
    return {"status": "ok"}


def _get_student_response(s, branch_name, class_name, parent_name, parent_phone):
    return {
        "id": str(s.id),
        "admission_number": s.admission_number,
        "name": s.name,
        "date_of_birth": s.date_of_birth.isoformat() if s.date_of_birth else None,
        "age_years": s.age_years,
        "age_months": s.age_months,
        "gender": s.gender,
        "place_of_birth": s.place_of_birth,
        "nationality": s.nationality,
        "religion": s.religion,
        "mother_tongue": s.mother_tongue,
        "blood_group": s.blood_group,
        "medical_allergies": s.medical_allergies,
        "medical_surgeries": s.medical_surgeries,
        "medical_chronic_illness": s.medical_chronic_illness,
        "branch_id": str(s.branch_id) if s.branch_id else None,
        "branch_name": branch_name,
        "class_id": str(s.class_id) if s.class_id else None,
        "class_name": class_name,
        "residential_address": s.residential_address,
        "residential_contact_no": s.residential_contact_no,
        "father_name": s.father_name,
        "father_occupation": s.father_occupation,
        "father_contact_no": s.father_contact_no,
        "father_email": s.father_email,
        "mother_name": s.mother_name,
        "mother_occupation": s.mother_occupation,
        "mother_contact_no": s.mother_contact_no,
        "mother_email": s.mother_email,
        "guardian_name": s.guardian_name,
        "guardian_relation": s.guardian_relation,
        "guardian_contact_no": s.guardian_contact_no,
        "emergency_contact_name": s.emergency_contact_name,
        "emergency_contact_phone": s.emergency_contact_phone,
        "parent_name": parent_name or s.father_name or s.mother_name,
        "parent_phone": parent_phone or s.father_contact_no or s.mother_contact_no or s.residential_contact_no,
        "transport_required": s.transport_required,
        "declaration_date": s.declaration_date.isoformat() if s.declaration_date else None,
    }


@app.get("/api/v1/admin/students/{student_id}")
@app.get("/api/v1/student/{student_id}")
def get_student(
    student_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    """Get a single student by ID for profile view."""
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Student not found")
    branch_name = None
    class_name = None
    if s.branch_id:
        branch = db.query(Branch).filter(Branch.id == s.branch_id).first()
        branch_name = branch.name if branch else None
    if s.class_id:
        cls = db.query(Class).filter(Class.id == s.class_id).first()
        class_name = cls.name if cls else None
    parent_name = None
    parent_phone = None
    if s.parent_links:
        try:
            parent_name = s.parent_links[0].user.full_name
            parent_phone = s.parent_links[0].user.phone
        except Exception:
            pass
    return _get_student_response(s, branch_name, class_name, parent_name, parent_phone)


@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)
