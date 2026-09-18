"""Admission-document digitization.

Flow (fully automatic — no manual "review and click apply" step in the
normal case):
  1. POST /documents            (admin/teacher/coordinator) - upload a scanned
     admission form (image or PDF) for a branch+class already selected (same
     as the manual admission form — OCR can't reliably infer which class a
     child belongs in). Saved to disk, an `IngestionDocument` row is created
     with status="pending", and — if N8N_WEBHOOK_URL is configured — the
     backend fires a background notification to n8n.
  2. n8n fetches the file via GET /documents/{id}/file (service token),
     OCRs/extracts it, and calls PATCH /documents/{id}/ocr-result (service
     token) with the structured data.
  3. The backend immediately validates the extracted data and, if it's
     usable, applies it right there in the same request: creates/updates the
     Student, the parent User and the ParentStudentLink — the exact same
     shapes the existing admission endpoints (`app/api/admission.py`)
     produce, via the same admission-number generator, and using the same
     "students"/"users"/"parent_student_links" tables. Status becomes
     "applied" and the student appears in the existing Admissions list
     immediately. n8n itself never writes to `students`/`users` directly.
  4. Only if required fields are missing, unreadable, or a likely-duplicate
     student/parent is detected does a document stop at status="failed" with
     a clear `error_message` — never silently "pending" forever. A human can
     then open it and call POST /documents/{id}/apply manually (same
     endpoint the automatic path uses internally) after fixing the data.

Parents have no access to any endpoint in this router — admission digitization
is staff-only, matching the requirement that parents cannot upload or edit
admission forms.
"""
import logging
import os
from datetime import date as date_type, datetime, timezone
from typing import List, Optional
from uuid import UUID

import requests
from fastapi import (
    APIRouter,
    BackgroundTasks,
    Depends,
    File,
    Form,
    Header,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.core.auth import get_current_user, get_optional_user, require_service_token
from app.core.config import settings
from app.core.database import get_db
from app.core.security import decode_access_token, get_password_hash
from app.models.branch import Branch, Class
from app.models.document import IngestionDocument
from app.models.student import ParentStudentLink, Student
from app.models.user import User
from app.schemas.document import (
    DocumentApplyRequest,
    DocumentRejectRequest,
    IngestionDocumentResponse,
    OcrResultIn,
)
from app.services.class_access import can_manage_branch_gallery, get_user_branch_ids
from app.services.document_match import (
    find_candidate_parents,
    find_candidate_parents_by_phone,
    find_candidate_students,
)
from app.services.media_files import mime_for_filename, save_upload_file

router = APIRouter(prefix="/documents", tags=["documents"])

DOCUMENTS_DIR = os.path.join("uploads", "ingestion_documents")
os.makedirs(DOCUMENTS_DIR, exist_ok=True)

STAFF_ROLES = ("admin", "teacher", "coordinator")


def _require_staff_role(user: User) -> None:
    if user.role not in STAFF_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only admins, coordinators and teachers can manage admission documents",
        )


def _require_branch_access(db: Session, user: User, branch_id: UUID) -> None:
    if not can_manage_branch_gallery(db, user, branch_id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to access documents for this branch",
        )


def _resolve_request_user(db: Session, current_user: Optional[User], token: Optional[str]) -> User:
    """Same query-param JWT fallback used by gallery.py so an <img>/<iframe>
    tag without custom headers can still load a protected file."""
    if current_user:
        return current_user
    if not token:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    payload = decode_access_token(token)
    user_id = payload.get("sub") if payload else None
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")
    user = db.query(User).filter(User.id == UUID(user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user


def _get_doc_or_404(db: Session, document_id: UUID) -> IngestionDocument:
    doc = db.query(IngestionDocument).filter(IngestionDocument.id == document_id).first()
    if not doc:
        raise HTTPException(status_code=404, detail="Document not found")
    return doc


def _serialize(db: Session, doc: IngestionDocument) -> IngestionDocumentResponse:
    branch = db.query(Branch).filter(Branch.id == doc.branch_id).first()
    uploader = db.query(User).filter(User.id == doc.uploaded_by).first()
    matched_student = (
        db.query(Student).filter(Student.id == doc.matched_student_id).first()
        if doc.matched_student_id
        else None
    )
    return IngestionDocumentResponse(
        id=doc.id,
        branch_id=doc.branch_id,
        branch_name=branch.name if branch else None,
        doc_type=doc.doc_type,
        status=doc.status,
        file_name=doc.file_name,
        file_mime=doc.file_mime,
        file_size=doc.file_size,
        uploaded_by=doc.uploaded_by,
        uploader_name=uploader.full_name if uploader else None,
        raw_ocr_data=doc.raw_ocr_data,
        extracted_data=doc.extracted_data,
        confidence_scores=doc.confidence_scores,
        matched_student_id=doc.matched_student_id,
        matched_student_name=matched_student.name if matched_student else None,
        matched_parent_user_id=doc.matched_parent_user_id,
        reviewed_by=doc.reviewed_by,
        reviewed_at=doc.reviewed_at.isoformat() if doc.reviewed_at else None,
        error_message=doc.error_message,
        created_at=doc.created_at.isoformat() if doc.created_at else None,
        updated_at=doc.updated_at.isoformat() if doc.updated_at else None,
    )


_logger = logging.getLogger(__name__)


def _notify_n8n(document_id: UUID, file_url: str, doc_type: str, branch_id: UUID) -> None:
    """Best-effort webhook call — never raises into the caller. If n8n isn't
    configured yet or is unreachable, the document just stays "pending" until
    someone hits POST /documents/{id}/retry-ocr once the workflow is set up.

    Every outcome is logged (including a non-2xx response from n8n, which
    `requests` does NOT raise for on its own) so a document silently stuck in
    "pending" is always diagnosable from app.log instead of failing silently."""
    if not settings.n8n_webhook_url:
        _logger.warning(
            "N8N_WEBHOOK_URL is not set; document %s left in status=pending. "
            "Configure it and call POST /documents/%s/retry-ocr once ready.",
            document_id,
            document_id,
        )
        return
    try:
        response = requests.post(
            settings.n8n_webhook_url,
            json={
                "document_id": str(document_id),
                "file_url": file_url,
                "doc_type": doc_type,
                "branch_id": str(branch_id),
            },
            headers={"X-Service-Token": settings.n8n_service_token} if settings.n8n_service_token else {},
            timeout=10,
        )
        if response.ok:
            _logger.info(
                "Notified n8n for document %s (HTTP %s)", document_id, response.status_code
            )
        else:
            _logger.warning(
                "n8n webhook rejected document %s: HTTP %s %s — body: %s",
                document_id,
                response.status_code,
                settings.n8n_webhook_url,
                response.text[:500],
            )
    except Exception:
        _logger.exception("Failed to reach n8n webhook for document %s", document_id)


def _file_url(document_id: UUID) -> str:
    base = settings.backend_public_base_url.rstrip("/")
    return f"{base}/api/v1/documents/{document_id}/file"


# --- Branch/class pickers ----------------------------------------------------
# `/admin/branches` and `/admin/classes` are admin-only (require_admin), but
# this feature is also used by teachers and coordinators, so — like
# `gallery.py`'s `/gallery/branch-options` — we expose branch-scoped pickers
# here instead.


@router.get("/branch-options")
def list_branch_options(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    _require_staff_role(user)
    branch_ids = get_user_branch_ids(db, user)
    q = db.query(Branch)
    if branch_ids is not None:
        if not branch_ids:
            return []
        q = q.filter(Branch.id.in_(branch_ids))
    branches = q.order_by(Branch.name.asc()).all()
    return [{"id": str(b.id), "name": b.name} for b in branches]


@router.get("/class-options")
def list_class_options(
    branch_id: UUID = Query(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    _require_staff_role(user)
    _require_branch_access(db, user, branch_id)
    classes = (
        db.query(Class)
        .filter(Class.branch_id == branch_id)
        .order_by(Class.name.asc())
        .all()
    )
    return [{"id": str(c.id), "name": c.name} for c in classes]


# --- Upload -----------------------------------------------------------------


@router.post("", response_model=IngestionDocumentResponse)
async def upload_document(
    background_tasks: BackgroundTasks,
    branch_id: UUID = Form(...),
    class_id: UUID = Form(...),
    doc_type: str = Form("admission_form"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Upload a scanned admission form (image or PDF). Admin/teacher/coordinator
    only, scoped to branches they're assigned to (admins: every branch).
    `class_id` is required up front (same as the manual admission form) so
    the OCR result can be auto-applied without pausing for a manual review
    step — OCR extracts the child/parent details, not which class they're in."""
    _require_staff_role(user)

    branch = db.query(Branch).filter(Branch.id == branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    _require_branch_access(db, user, branch_id)

    cls = db.query(Class).filter(Class.id == class_id, Class.branch_id == branch_id).first()
    if not cls:
        raise HTTPException(status_code=400, detail="Class not found or not in this branch")

    path, orig_name, size_label, mime = await save_upload_file(file, DOCUMENTS_DIR)

    doc = IngestionDocument(
        branch_id=branch_id,
        class_id=class_id,
        doc_type=doc_type or "admission_form",
        status="pending",
        file_path=path,
        file_name=orig_name,
        file_mime=mime,
        file_size=size_label,
        uploaded_by=user.id,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)

    background_tasks.add_task(
        _notify_n8n, doc.id, _file_url(doc.id), doc.doc_type, doc.branch_id
    )

    return _serialize(db, doc)


@router.get("", response_model=List[IngestionDocumentResponse])
def list_documents(
    status_filter: Optional[str] = Query(None, alias="status"),
    branch_id: Optional[UUID] = Query(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """List admission documents visible to the current user (their assigned
    branches; admins see every branch), optionally filtered by status."""
    _require_staff_role(user)

    branch_ids = get_user_branch_ids(db, user)
    q = db.query(IngestionDocument)
    if branch_ids is not None:
        if not branch_ids:
            return []
        q = q.filter(IngestionDocument.branch_id.in_(branch_ids))
    if branch_id is not None:
        if branch_ids is not None and branch_id not in branch_ids:
            raise HTTPException(status_code=403, detail="You don't have access to this branch")
        q = q.filter(IngestionDocument.branch_id == branch_id)
    if status_filter is not None:
        q = q.filter(IngestionDocument.status == status_filter)

    docs = q.order_by(IngestionDocument.created_at.desc()).all()
    return [_serialize(db, d) for d in docs]


@router.get("/{document_id}", response_model=IngestionDocumentResponse)
def get_document(
    document_id: UUID,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    _require_staff_role(user)
    doc = _get_doc_or_404(db, document_id)
    _require_branch_access(db, user, doc.branch_id)
    return _serialize(db, doc)


@router.get("/{document_id}/file")
def get_document_file(
    document_id: UUID,
    token: Optional[str] = Query(None),
    x_service_token: Optional[str] = Header(default=None, alias="X-Service-Token"),
    db: Session = Depends(get_db),
    current_user: Optional[User] = Depends(get_optional_user),
):
    """Stream the raw uploaded file. Reachable either by a staff user with
    branch access (JWT, or `?token=` for <img>/<iframe> tags) or by n8n using
    the shared `X-Service-Token` secret — no human login for n8n."""
    doc = _get_doc_or_404(db, document_id)

    is_service_call = bool(settings.n8n_service_token) and x_service_token == settings.n8n_service_token
    if not is_service_call:
        user = _resolve_request_user(db, current_user, token)
        _require_staff_role(user)
        _require_branch_access(db, user, doc.branch_id)

    if not os.path.exists(doc.file_path):
        raise HTTPException(status_code=404, detail="File not found")
    media = doc.file_mime or mime_for_filename(doc.file_name)
    return FileResponse(path=doc.file_path, filename=doc.file_name, media_type=media)


@router.post("/{document_id}/retry-ocr", response_model=IngestionDocumentResponse)
def retry_ocr(
    document_id: UUID,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Re-fire the n8n webhook — useful if n8n wasn't configured yet at
    upload time, or the previous OCR attempt failed."""
    _require_staff_role(user)
    doc = _get_doc_or_404(db, document_id)
    _require_branch_access(db, user, doc.branch_id)
    if doc.status not in ("pending", "failed"):
        raise HTTPException(status_code=400, detail="Only pending or failed documents can be retried")

    doc.status = "pending"
    doc.error_message = None
    db.commit()
    db.refresh(doc)

    background_tasks.add_task(
        _notify_n8n, doc.id, _file_url(doc.id), doc.doc_type, doc.branch_id
    )
    return _serialize(db, doc)


# --- Auto-apply: turning OCR output into a DocumentApplyRequest ---------------


def _compute_age(dob: date_type) -> tuple[int, int]:
    today = date_type.today()
    age_years = today.year - dob.year
    if (today.month, today.day) < (dob.month, dob.day):
        age_years -= 1
    age_months = age_years * 12 + (today.month - dob.month)
    return age_years, age_months


def _parse_ocr_date(raw: object) -> Optional[date_type]:
    """OCR output isn't always ISO `YYYY-MM-DD` — admission forms commonly
    read as `DD/MM/YYYY` or `DD-MM-YYYY`. Try ISO first, then those."""
    if not raw:
        return None
    text = str(raw).strip()
    try:
        return date_type.fromisoformat(text)
    except ValueError:
        pass
    import re

    m = re.match(r"^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$", text)
    if not m:
        return None
    day, month, year = int(m.group(1)), int(m.group(2)), int(m.group(3))
    try:
        return date_type(year, month, day)
    except ValueError:
        return None


def _build_apply_request_from_extracted(
    doc: IngestionDocument,
) -> tuple[Optional[DocumentApplyRequest], Optional[str]]:
    """Maps OCR `extracted_data` -> DocumentApplyRequest for automatic apply.
    Returns (request, None) on success or (None, error_message) when required
    fields are missing/unreadable — the caller stores that message as
    `error_message` and sets status="failed" instead of guessing or silently
    leaving the document pending."""
    data = doc.extracted_data or {}

    if not doc.class_id:
        return None, (
            "No class was selected when this document was uploaded, so it can't be "
            "auto-applied. Open it and apply manually after choosing a class."
        )

    missing: list[str] = []

    name = str(data.get("name") or "").strip()
    if not name:
        missing.append("child's name")

    dob = _parse_ocr_date(data.get("date_of_birth"))
    if not dob:
        missing.append("date of birth (readable as YYYY-MM-DD or DD/MM/YYYY)")

    # OCR rarely produces a literal "parent_name" — fall back to whichever
    # parent/guardian name it did extract, same priority a human filling the
    # manual admission form would use.
    parent_name = str(
        data.get("parent_name")
        or data.get("father_name")
        or data.get("mother_name")
        or data.get("guardian_name")
        or ""
    ).strip()
    if not parent_name:
        missing.append("parent/guardian name")

    if missing:
        return None, "OCR did not extract a usable " + ", ".join(missing) + ". Open the document and apply manually with corrected data."

    def _s(key: str) -> Optional[str]:
        v = data.get(key)
        return str(v).strip() or None if v is not None else None

    def _b(key: str) -> bool:
        return bool(data.get(key)) is True

    request = DocumentApplyRequest(
        mode="create_student",
        branch_id=doc.branch_id,
        class_id=doc.class_id,
        name=name,
        date_of_birth=dob,
        gender=_s("gender"),
        place_of_birth=_s("place_of_birth"),
        nationality=_s("nationality"),
        mother_tongue=_s("mother_tongue"),
        religion=_s("religion"),
        blood_group=_s("blood_group"),
        medical_allergies=_s("medical_allergies"),
        medical_surgeries=_s("medical_surgeries"),
        medical_chronic_illness=_s("medical_chronic_illness"),
        residential_address=_s("residential_address"),
        residential_contact_no=_s("residential_contact_no"),
        attended_previously=_b("attended_previously"),
        school_daycare_name=_s("school_daycare_name"),
        prev_school_duration=_s("prev_school_duration"),
        prev_school_class=_s("prev_school_class"),
        birth_certificate=_b("birth_certificate"),
        immunization_record=_b("immunization_record"),
        transfer_certificate=_b("transfer_certificate"),
        passport_photos=_b("passport_photos"),
        progress_report=_b("progress_report"),
        passport=_b("passport"),
        other_medical_report=_b("other_medical_report"),
        parent_name=parent_name,
        parent_contact=_s("parent_contact") or _s("father_contact_no") or _s("mother_contact_no"),
        father_name=_s("father_name"),
        father_occupation=_s("father_occupation"),
        father_contact_no=_s("father_contact_no"),
        father_email=_s("father_email"),
        mother_name=_s("mother_name"),
        mother_occupation=_s("mother_occupation"),
        mother_contact_no=_s("mother_contact_no"),
        mother_email=_s("mother_email"),
        guardian_name=_s("guardian_name"),
        guardian_relation=_s("guardian_relation"),
        guardian_contact_no=_s("guardian_contact_no"),
        emergency_contact_name=_s("emergency_contact_name"),
        emergency_contact_phone=_s("emergency_contact_phone"),
        transport_required=_b("transport_required"),
    )
    return request, None


def _conflict_message(exc: HTTPException) -> str:
    detail = exc.detail
    if isinstance(detail, dict) and "message" in detail:
        return str(detail["message"])
    return str(detail)


# --- n8n callback -------------------------------------------------------------


@router.patch("/{document_id}/ocr-result", response_model=IngestionDocumentResponse)
def submit_ocr_result(
    document_id: UUID,
    data: OcrResultIn,
    db: Session = Depends(get_db),
    _: None = Depends(require_service_token),
):
    """n8n calls this once OCR/AI extraction finishes. Service-token auth
    only — never reachable by a logged-in app user. Unlike a plain "store and
    wait for review" callback, this immediately attempts to apply the result:
    on success the student is already in the Admissions list and has a
    working Parent Portal login by the time this call returns; on missing
    data or a likely duplicate, status becomes "failed" with a clear
    `error_message` instead of leaving the document silently pending."""
    doc = _get_doc_or_404(db, document_id)
    if doc.status in ("applied", "rejected"):
        raise HTTPException(
            status_code=409,
            detail="Document has already been reviewed; ignoring stale OCR result",
        )
    if data.status not in ("needs_review", "failed"):
        raise HTTPException(status_code=400, detail="status must be needs_review or failed")

    doc.raw_ocr_data = data.raw_ocr_data
    doc.extracted_data = data.extracted_data
    doc.confidence_scores = data.confidence_scores

    if data.status == "failed":
        doc.status = "failed"
        doc.error_message = data.error_message or "n8n reported OCR extraction failed."
        db.commit()
        db.refresh(doc)
        return _serialize(db, doc)

    apply_request, validation_error = _build_apply_request_from_extracted(doc)
    if validation_error:
        doc.status = "failed"
        doc.error_message = validation_error
        db.commit()
        db.refresh(doc)
        _logger.warning("Auto-apply skipped for document %s: %s", document_id, validation_error)
        return _serialize(db, doc)

    try:
        _perform_apply(db, doc, apply_request, applied_by=None)
        db.commit()
        _logger.info("Auto-applied document %s -> student %s", document_id, doc.matched_student_id)
    except HTTPException as exc:
        db.rollback()
        doc.status = "failed"
        doc.error_message = _conflict_message(exc)
        db.commit()
        _logger.warning("Auto-apply blocked for document %s: %s", document_id, doc.error_message)

    db.refresh(doc)
    return _serialize(db, doc)


def _apply_student_fields(student: Student, data: DocumentApplyRequest) -> None:
    age_years, age_months = _compute_age(data.date_of_birth)
    student.name = data.name
    student.date_of_birth = data.date_of_birth
    student.age_years = age_years
    student.age_months = age_months
    student.gender = data.gender
    student.place_of_birth = data.place_of_birth
    student.nationality = data.nationality
    student.mother_tongue = data.mother_tongue
    student.religion = data.religion
    student.blood_group = data.blood_group
    student.medical_allergies = data.medical_allergies
    student.medical_surgeries = data.medical_surgeries
    student.medical_chronic_illness = data.medical_chronic_illness
    student.class_id = data.class_id
    student.branch_id = data.branch_id
    student.residential_address = data.residential_address
    student.residential_contact_no = data.residential_contact_no
    student.father_name = data.father_name
    student.father_occupation = data.father_occupation
    student.father_contact_no = data.father_contact_no
    student.father_email = data.father_email
    student.mother_name = data.mother_name
    student.mother_occupation = data.mother_occupation
    student.mother_contact_no = data.mother_contact_no
    student.mother_email = data.mother_email
    student.guardian_name = data.guardian_name
    student.guardian_relation = data.guardian_relation
    student.guardian_contact_no = data.guardian_contact_no
    student.emergency_contact_name = data.emergency_contact_name
    student.emergency_contact_phone = data.emergency_contact_phone
    student.transport_required = data.transport_required
    student.attended_previously = data.attended_previously
    student.school_daycare_name = data.school_daycare_name
    student.prev_school_duration = data.prev_school_duration
    student.prev_school_class = data.prev_school_class
    student.birth_certificate = data.birth_certificate
    student.immunization_record = data.immunization_record
    student.transfer_certificate = data.transfer_certificate
    student.passport_photos = data.passport_photos
    student.progress_report = data.progress_report
    student.passport = data.passport
    student.other_medical_report = data.other_medical_report


def _perform_apply(
    db: Session,
    doc: IngestionDocument,
    data: DocumentApplyRequest,
    applied_by: Optional[User],
) -> Student:
    """Does the actual write to `students` / `users` / `parent_student_links`
    and marks `doc` applied. Shared by the human-triggered POST .../apply
    endpoint and the automatic path in submit_ocr_result — one code path,
    reusing the exact same admission-number generator and Student/User/
    ParentStudentLink shapes as `app/api/admission.py`, so a document-derived
    student is indistinguishable from a manually-admitted one.

    Raises HTTPException (400/404/409) on bad input or a likely duplicate.
    Does NOT commit — the caller controls the transaction boundary so a
    crash mid-way never leaves an orphaned Student without its parent link.
    `applied_by=None` means system/automatic (no human reviewer)."""
    if data.mode not in ("create_student", "update_student"):
        raise HTTPException(status_code=400, detail="mode must be create_student or update_student")
    if doc.branch_id != data.branch_id:
        raise HTTPException(status_code=400, detail="branch_id must match the document's branch")

    branch = db.query(Branch).filter(Branch.id == data.branch_id).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")
    cls = db.query(Class).filter(Class.id == data.class_id, Class.branch_id == data.branch_id).first()
    if not cls:
        raise HTTPException(status_code=400, detail="Class not found or not in this branch")

    if data.mode == "create_student":
        if not data.force_new_student:
            dupes = find_candidate_students(
                db, name=data.name, date_of_birth=data.date_of_birth, branch_id=data.branch_id
            )
            if dupes:
                raise HTTPException(
                    status_code=409,
                    detail={
                        "message": "Possible duplicate student(s) found in this branch with the same date of birth: "
                        + ", ".join(f"{s.name} (#{s.admission_number})" for s in dupes)
                        + ". Pick one to update instead, or resubmit with force_new_student=true to confirm this is a new child.",
                        "candidates": [
                            {"id": str(s.id), "name": s.name, "admission_number": s.admission_number}
                            for s in dupes
                        ],
                    },
                )

        from app.api.admin import _generate_admission_number_for_branch

        admission_number = _generate_admission_number_for_branch(db, branch, date_type.today())
        student = Student(
            admission_number=admission_number,
            declaration_date=date_type.today(),
        )
        _apply_student_fields(student, data)
        db.add(student)
        db.flush()
    else:
        if not data.student_id:
            raise HTTPException(status_code=400, detail="student_id is required for update_student mode")
        student = db.query(Student).filter(Student.id == data.student_id).first()
        if not student:
            raise HTTPException(status_code=404, detail="Student not found")
        _apply_student_fields(student, data)
        db.flush()

    if data.parent_user_id:
        parent = db.query(User).filter(User.id == data.parent_user_id).first()
        if not parent:
            raise HTTPException(status_code=404, detail="Parent user not found")
    else:
        phone = data.parent_contact or data.father_contact_no or data.mother_contact_no
        phone_matches = [] if data.force_new_parent else find_candidate_parents_by_phone(db, phone=phone)
        if len(phone_matches) == 1:
            # Exactly one phone match (e.g. a sibling's existing parent) —
            # strong enough signal to auto-link without asking.
            parent = phone_matches[0]
        elif len(phone_matches) > 1:
            raise HTTPException(
                status_code=409,
                detail={
                    "message": "Multiple existing parents share this phone number — pass parent_user_id to pick one, "
                    "or resubmit with force_new_parent=true to confirm this is a new parent login.",
                    "candidates": [
                        {"id": str(c.id), "name": c.full_name, "phone": c.phone} for c in phone_matches
                    ],
                },
            )
        elif not data.force_new_parent and (
            broader := find_candidate_parents(db, phone=phone, name=data.parent_name)
        ):
            # No phone match, but a name-only match exists — too weak to
            # auto-link silently; surface it and let a human decide.
            raise HTTPException(
                status_code=409,
                detail={
                    "message": "A parent with a matching name (but different/no phone on file) already exists. "
                    "Pass parent_user_id to reuse them, or resubmit with force_new_parent=true to confirm this is a new parent login.",
                    "candidates": [
                        {"id": str(c.id), "name": c.full_name, "phone": c.phone} for c in broader
                    ],
                },
            )
        else:
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
            db.flush()

    existing_link = (
        db.query(ParentStudentLink)
        .filter(ParentStudentLink.student_id == student.id, ParentStudentLink.user_id == parent.id)
        .first()
    )
    if not existing_link:
        db.add(ParentStudentLink(user_id=parent.id, student_id=student.id, is_primary=True))

    doc.status = "applied"
    doc.matched_student_id = student.id
    doc.matched_parent_user_id = parent.id
    doc.reviewed_by = applied_by.id if applied_by else None
    doc.reviewed_at = datetime.now(timezone.utc)

    return student


@router.post("/{document_id}/apply", response_model=IngestionDocumentResponse)
def apply_document(
    document_id: UUID,
    data: DocumentApplyRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    """Manual fallback for a document that couldn't be auto-applied (missing
    fields, or a duplicate the automatic path wouldn't risk resolving on its
    own) — same `_perform_apply` the automatic path uses, single transaction."""
    _require_staff_role(user)
    doc = _get_doc_or_404(db, document_id)
    _require_branch_access(db, user, doc.branch_id)

    if doc.status not in ("needs_review", "failed"):
        raise HTTPException(status_code=400, detail="Document is not awaiting review")

    try:
        _perform_apply(db, doc, data, applied_by=user)
        db.commit()
    except HTTPException:
        db.rollback()
        raise
    except Exception:
        db.rollback()
        raise

    db.refresh(doc)
    return _serialize(db, doc)


@router.post("/{document_id}/reject", response_model=IngestionDocumentResponse)
def reject_document(
    document_id: UUID,
    data: DocumentRejectRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    _require_staff_role(user)
    doc = _get_doc_or_404(db, document_id)
    _require_branch_access(db, user, doc.branch_id)
    if doc.status in ("applied", "rejected"):
        raise HTTPException(status_code=400, detail="Document has already been finalized")

    doc.status = "rejected"
    doc.error_message = data.reason
    doc.reviewed_by = user.id
    doc.reviewed_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(doc)
    return _serialize(db, doc)
