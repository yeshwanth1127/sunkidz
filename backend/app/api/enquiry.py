from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.auth import require_admin
from app.models.user import User
from app.models.enquiry import Enquiry
from app.models.branch import Branch
from app.schemas.enquiry import EnquiryCreate, EnquiryResponse, EnquiryDetailResponse

router = APIRouter(prefix="/admin/enquiries", tags=["enquiries"])


@router.get("", response_model=list[EnquiryResponse])
def list_enquiries(
    status: str | None = Query(None),
    branch_id: UUID | None = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    q = db.query(Enquiry)
    if status:
        q = q.filter(Enquiry.status == status)
    if branch_id:
        q = q.filter(Enquiry.branch_id == branch_id)
    enquiries = q.order_by(Enquiry.created_at.desc()).all()
    result = []
    for e in enquiries:
        branch_name = None
        if e.branch_id:
            branch = db.query(Branch).filter(Branch.id == e.branch_id).first()
            branch_name = branch.name if branch else None
        result.append(EnquiryResponse(
            id=str(e.id),
            child_name=e.child_name,
            date_of_birth=e.date_of_birth.isoformat() if e.date_of_birth else None,
            age_years=e.age_years,
            age_months=e.age_months,
            gender=e.gender,
            father_name=e.father_name,
            mother_name=e.mother_name,
            father_contact_no=e.father_contact_no,
            mother_contact_no=e.mother_contact_no,
            residential_address=e.residential_address,
            branch_id=str(e.branch_id) if e.branch_id else None,
            branch_name=branch_name,
            status=e.status or "pending",
            created_at=e.created_at.isoformat() if e.created_at else None,
        ))
    return result


@router.post("", response_model=EnquiryResponse)
def create_enquiry(
    data: EnquiryCreate,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    e = Enquiry(
        child_name=data.child_name,
        date_of_birth=data.date_of_birth,
        age_years=data.age_years,
        age_months=data.age_months,
        gender=data.gender,
        father_name=data.father_name,
        father_occupation=data.father_occupation,
        father_place_of_work=data.father_place_of_work,
        father_email=data.father_email,
        father_contact_no=data.father_contact_no,
        mother_name=data.mother_name,
        mother_occupation=data.mother_occupation,
        mother_place_of_work=data.mother_place_of_work,
        mother_email=data.mother_email,
        mother_contact_no=data.mother_contact_no,
        siblings_info=data.siblings_info,
        siblings_age=data.siblings_age,
        residential_address=data.residential_address,
        residential_contact_no=data.residential_contact_no,
        challenges_specialities=data.challenges_specialities,
        expectations_from_school=data.expectations_from_school,
        branch_id=data.branch_id,
        status=data.status,
    )
    db.add(e)
    db.commit()
    db.refresh(e)
    branch_name = None
    if e.branch_id:
        branch = db.query(Branch).filter(Branch.id == e.branch_id).first()
        branch_name = branch.name if branch else None
    return EnquiryResponse(
        id=str(e.id),
        child_name=e.child_name,
        date_of_birth=e.date_of_birth.isoformat() if e.date_of_birth else None,
        age_years=e.age_years,
        age_months=e.age_months,
        gender=e.gender,
        father_name=e.father_name,
        mother_name=e.mother_name,
        father_contact_no=e.father_contact_no,
        mother_contact_no=e.mother_contact_no,
        residential_address=e.residential_address,
        branch_id=str(e.branch_id) if e.branch_id else None,
        branch_name=branch_name,
        status=e.status or "pending",
        created_at=e.created_at.isoformat() if e.created_at else None,
    )


@router.get("/{enquiry_id}", response_model=EnquiryDetailResponse)
def get_enquiry(
    enquiry_id: UUID,
    db: Session = Depends(get_db),
    _: User = Depends(require_admin),
):
    e = db.query(Enquiry).filter(Enquiry.id == enquiry_id).first()
    if not e:
        raise HTTPException(status_code=404, detail="Enquiry not found")
    branch_name = None
    if e.branch_id:
        branch = db.query(Branch).filter(Branch.id == e.branch_id).first()
        branch_name = branch.name if branch else None
    return EnquiryDetailResponse(
        id=str(e.id),
        child_name=e.child_name,
        date_of_birth=e.date_of_birth.isoformat() if e.date_of_birth else None,
        age_years=e.age_years,
        age_months=e.age_months,
        gender=e.gender,
        father_name=e.father_name,
        mother_name=e.mother_name,
        father_contact_no=e.father_contact_no,
        mother_contact_no=e.mother_contact_no,
        residential_address=e.residential_address,
        branch_id=str(e.branch_id) if e.branch_id else None,
        branch_name=branch_name,
        status=e.status or "pending",
        created_at=e.created_at.isoformat() if e.created_at else None,
        father_occupation=e.father_occupation,
        father_place_of_work=e.father_place_of_work,
        father_email=e.father_email,
        mother_occupation=e.mother_occupation,
        mother_place_of_work=e.mother_place_of_work,
        mother_email=e.mother_email,
        siblings_info=e.siblings_info,
        siblings_age=e.siblings_age,
        residential_contact_no=e.residential_contact_no,
        challenges_specialities=e.challenges_specialities,
        expectations_from_school=e.expectations_from_school,
    )
