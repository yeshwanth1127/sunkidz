"""Keep every branch's ``classes`` rows in sync with the 4 canonical levels.

Single source of truth for the branch grade/class options used by every
dropdown in the app (Daily Reports, Marks Card, Attendance, Almanac, Diary,
Syllabus, Homework, Learning Modules, Messages, ...). All of those read the
``classes`` table for the branch, so a branch that is missing (say) a
Playgroup row hides Playgroup everywhere at once.

Additive + alias-normalizing only: this never deletes a class (custom or
canonical) and never renames one that would collide.
"""
import logging

from sqlalchemy.orm import Session

from app.core.class_names import STANDARD_CLASSES, normalize_class_name
from app.models.branch import Branch, Class

logger = logging.getLogger(__name__)


def ensure_standard_classes(db: Session) -> int:
    """For every branch, insert whichever of Playgroup / IG1 / IG2 / IG3 it
    does not already have (matched case/space/dash-insensitively against the
    current + legacy spellings so an existing row is never duplicated).

    Returns the number of class rows inserted. Idempotent — a no-op once every
    branch has all four.
    """
    inserted = 0
    for branch in db.query(Branch).all():
        have = {
            normalize_class_name(c.name)
            for c in db.query(Class).filter(Class.branch_id == branch.id).all()
        }
        for name in STANDARD_CLASSES:
            if name not in have:
                db.add(
                    Class(branch_id=branch.id, name=name, academic_year="2026-27")
                )
                inserted += 1
    if inserted:
        db.commit()
        logger.info("ensure_standard_classes: added %d missing branch class rows", inserted)
    return inserted
