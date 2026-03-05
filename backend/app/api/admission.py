"""Convert enquiry to admission. Creates student, parent user, links them."""
from datetime import date
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import require_admin
from app.core.security import get_password_hash
from app.models.user import User
from app.models.enquiry import Enquiry
from app.models.student import Student
from app.models.branch import Branch, Class
from app.models.student import ParentStudentLink
from app.schemas.admission import AdmissionCreate

router = APIRouter(prefix="/admin/admissions", tags=["admissions"])


def _generate_admission_number(db: Session, branch: Branch, admission_date: date) -> str:
    """Format: skz(branch_code)(year)(date) e.g. skzmain20250304"""
    code = (branch.code or "main").lower()[:10]
    year = admission_date.strftime("%Y")
    day = admission_date.strftime("%m%d")  # MMDD
    base = f"skz{code}{year}{day}"
    # Check for duplicates
    existing = db.query(Student).filter(Student.admission_number.like(f"{base}%")).count()
    if existing > 0:
        return f"{base}{existing + 1:02d}"
    return base


@router.post("/from-enquiry")
def create_admission_from_enquiry(
    data: AdmissionCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    enquiry = db.query(Enquiry).filter(Enquiry.id == data.enquiry_id).first()
    if not enquiry:
        raise HTTPException(status_code=404, detail="Enquiry not found")
    if enquiry.status == "converted":
        raise HTTPException(status_code=400, detail="Enquiry already converted to admission")

    branch = db.query(Branch).filter(Branch.id == data.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    cls = db.query(Class).filter(Class.id == data.class_id, Class.branch_id == data.branch_id).first()
    if not cls:
        raise HTTPException(status_code=400, detail="Class not found or not in this branch")

    admission_date = date.today()
    admission_number = _generate_admission_number(db, branch, admission_date)

    # Create parent user - password = DOB (YYYY-MM-DD)
    dob_str = data.date_of_birth.isoformat()
    parent = User(
        email=None,
        password_hash=get_password_hash(dob_str),
        full_name=data.parent_name,
        role="parent",
        phone=data.parent_contact,
        is_active="true",
    )
    db.add(parent)
    db.commit()
    db.refresh(parent)

    # Create student
    age_years = None
    age_months = None
    if data.date_of_birth:
        today = date.today()
        age_years = today.year - data.date_of_birth.year
        if (today.month, today.day) < (data.date_of_birth.month, data.date_of_birth.day):
            age_years -= 1
        age_months = age_years * 12 + (today.month - data.date_of_birth.month)

    student = Student(
        admission_number=admission_number,
        name=data.name,
        date_of_birth=data.date_of_birth,
        age_years=age_years,
        age_months=age_months,
        gender=data.gender,
        place_of_birth=data.place_of_birth,
        nationality=data.nationality,
        mother_tongue=data.mother_tongue,
        religion=data.religion,
        blood_group=data.blood_group,
        medical_allergies=data.medical_allergies,
        medical_surgeries=data.medical_surgeries,
        medical_chronic_illness=data.medical_chronic_illness,
        class_id=data.class_id,
        branch_id=data.branch_id,
        enquiry_id=data.enquiry_id,
        residential_address=data.residential_address,
        residential_contact_no=data.residential_contact_no,
        father_name=data.father_name,
        father_occupation=data.father_occupation,
        father_contact_no=data.father_contact_no,
        father_email=data.father_email,
        mother_name=data.mother_name,
        mother_occupation=data.mother_occupation,
        mother_contact_no=data.mother_contact_no,
        mother_email=data.mother_email,
        guardian_name=data.guardian_name,
        guardian_relation=data.guardian_relation,
        guardian_contact_no=data.guardian_contact_no,
        emergency_contact_name=data.emergency_contact_name,
        emergency_contact_phone=data.emergency_contact_phone,
        transport_required=data.transport_required,
        attended_previously=data.attended_previously,
        school_daycare_name=data.school_daycare_name,
        prev_school_duration=data.prev_school_duration,
        prev_school_class=data.prev_school_class,
        birth_certificate=data.birth_certificate,
        immunization_record=data.immunization_record,
        transfer_certificate=data.transfer_certificate,
        passport_photos=data.passport_photos,
        progress_report=data.progress_report,
        passport=data.passport,
        other_medical_report=data.other_medical_report,
        declaration_date=admission_date,
    )
    db.add(student)
    db.commit()
    db.refresh(student)

    # Link parent to student
    db.add(ParentStudentLink(user_id=parent.id, student_id=student.id, is_primary=True))
    db.commit()

    # Mark enquiry as converted
    enquiry.status = "converted"
    db.commit()

    return {
        "admission_number": admission_number,
        "student_id": str(student.id),
        "parent_id": str(parent.id),
        "message": f"Admission created. Parent can login with admission_number={admission_number} and date_of_birth={dob_str}",
    }
