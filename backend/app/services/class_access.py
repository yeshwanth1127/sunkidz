"""Shared class/branch access checks for syllabus, diary, almanac."""
from typing import List, Optional
from uuid import UUID
from sqlalchemy.orm import Session

from app.models.user import User
from app.models.student import Student, ParentStudentLink
from app.models.branch import Class, BranchAssignment


def get_user_class_ids(db: Session, user: User) -> Optional[List[UUID]]:
    if user.role == "admin":
        return None
    if user.role == "coordinator":
        assignments = db.query(BranchAssignment).filter(
            BranchAssignment.user_id == user.id,
            BranchAssignment.branch_id.isnot(None),
        ).all()
        if not assignments:
            return []
        branch_ids = [a.branch_id for a in assignments]
        classes = db.query(Class).filter(Class.branch_id.in_(branch_ids)).all()
        return [c.id for c in classes]
    assignments = db.query(BranchAssignment).filter(
        BranchAssignment.user_id == user.id,
        BranchAssignment.class_id.isnot(None),
    ).all()
    return [a.class_id for a in assignments]


def can_upload_to_class(db: Session, user: User, class_id: UUID) -> bool:
    if user.role == "admin":
        return True
    if user.role in ("teacher", "coordinator"):
        user_classes = get_user_class_ids(db, user)
        return class_id in user_classes if user_classes else False
    return False


def can_view_class(db: Session, user: User, class_id: UUID) -> bool:
    if user.role in ("admin", "coordinator", "toddlers", "daycare"):
        return True
    if user.role == "teacher":
        user_classes = get_user_class_ids(db, user)
        return class_id in user_classes if user_classes else False
    if user.role == "parent":
        parent_links = db.query(ParentStudentLink).filter(
            ParentStudentLink.user_id == user.id
        ).all()
        student_ids = [link.student_id for link in parent_links]
        if student_ids:
            children = db.query(Student).filter(Student.id.in_(student_ids)).all()
            children_class_ids = [child.class_id for child in children if child.class_id]
            return class_id in children_class_ids
    return False
