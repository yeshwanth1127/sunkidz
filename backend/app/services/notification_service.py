"""
Notification service for handling WhatsApp notifications.
Handles: enquiry submissions, fee updates, syllabus uploads, homework uploads.
"""

import logging
from typing import Optional, List
from uuid import UUID
from sqlalchemy.orm import Session

from app.models.enquiry import Enquiry
from app.models.student import Student, ParentStudentLink
from app.models.user import User
from app.models.fees import FeeStructure
from app.models.syllabus import Syllabus, Homework
from app.services.whatsapp_service import whatsapp_service

logger = logging.getLogger(__name__)


def send_enquiry_notification(enquiry: Enquiry) -> bool:
    """
    Send WhatsApp notification to parent after enquiry submission.
    
    Business logic:
    - Prefer father's contact number if available
    - Fall back to mother's contact number if father's is not available
    - Skip if no contact number is available
    
    Args:
        enquiry: The enquiry object with parent contact information
        
    Returns:
        True if notification was sent successfully, False otherwise
    """
    # Determine which contact to use
    contact_number: Optional[str] = None
    contact_type: str = ""
    
    if enquiry.father_contact_no:
        contact_number = enquiry.father_contact_no
        contact_type = "father"
    elif enquiry.mother_contact_no:
        contact_number = enquiry.mother_contact_no
        contact_type = "mother"
    else:
        logger.warning(
            f"No contact number available for enquiry ID {enquiry.id} (child: {enquiry.child_name})"
        )
        return False
    
    logger.info(
        f"Sending enquiry notification for {enquiry.child_name} to {contact_type}'s number: {contact_number}"
    )
    
    # Send WhatsApp message
    try:
        success = whatsapp_service.send_welcome_message(
            phone_number=contact_number,
            child_name=enquiry.child_name
        )
        
        if success:
            logger.info(
                f"Successfully sent enquiry notification for enquiry ID {enquiry.id}"
            )
        else:
            logger.error(
                f"Failed to send enquiry notification for enquiry ID {enquiry.id}"
            )
        
        return success
        
    except Exception as e:
        logger.error(
            f"Exception while sending enquiry notification for enquiry ID {enquiry.id}: {str(e)}"
        )
        return False


def send_fee_notification(student_id: UUID, db: Session) -> bool:
    """
    Send WhatsApp notification to parents when fee structure is setup/updated.
    
    Args:
        student_id: ID of the student whose fee was updated
        db: Database session
        
    Returns:
        True if notification was sent successfully, False otherwise
    """
    try:
        # Get student information
        student = db.query(Student).filter(Student.id == student_id).first()
        if not student:
            logger.warning(f"Student not found with ID {student_id}")
            return False
        
        # Get parent links for this student
        parent_links = db.query(ParentStudentLink).filter(
            ParentStudentLink.student_id == student_id
        ).all()
        
        if not parent_links:
            logger.warning(f"No parent found for student {student_id}")
            return False
        
        success_count = 0
        total_attempts = len(parent_links)
        
        # Send notification to all parents
        for parent_link in parent_links:
            parent_user = db.query(User).filter(User.id == parent_link.user_id).first()
            if not parent_user or not parent_user.phone_no:
                logger.warning(f"Parent {parent_link.user_id} has no phone number")
                continue
            
            try:
                success = whatsapp_service.send_fee_notification(
                    phone_number=parent_user.phone_no,
                    student_name=student.name,
                    child_name=student.name
                )
                if success:
                    success_count += 1
                    logger.info(f"Fee notification sent to parent: {parent_user.phone_no}")
                else:
                    logger.warning(f"Failed to send fee notification to {parent_user.phone_no}")
            except Exception as e:
                logger.error(f"Exception sending fee notification: {str(e)}")
        
        logger.info(f"Fee notifications sent to {success_count}/{total_attempts} parents")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Exception in send_fee_notification: {str(e)}")
        return False


def send_syllabus_notification(syllabus: Syllabus, db: Session) -> bool:
    """
    Send WhatsApp notification to staff when syllabus is uploaded.
    
    Args:
        syllabus: The syllabus object
        db: Database session
        
    Returns:
        True if notification was sent, False otherwise
    """
    try:
        # Get all staff (teachers and coordinators) in the class
        from app.models.branch import BranchAssignment
        
        class_info = db.query("Class").filter_by(id=syllabus.class_id).first()
        
        # Get staff assignments for this class
        staff_assignments = db.query(BranchAssignment).filter(
            BranchAssignment.class_id == syllabus.class_id
        ).all()
        
        if not staff_assignments:
            logger.warning(f"No staff assigned to class {syllabus.class_id}")
            return False
        
        success_count = 0
        
        # Get uploader name
        uploader = db.query(User).filter(User.id == syllabus.uploaded_by).first()
        uploader_name = uploader.full_name if uploader else "Admin"
        
        # Send notification to all assigned staff
        for assignment in staff_assignments:
            staff = db.query(User).filter(User.id == assignment.user_id).first()
            if not staff or not staff.phone_no:
                continue
            
            try:
                # Get class name
                from app.models.branch import Class
                class_obj = db.query(Class).filter(Class.id == syllabus.class_id).first()
                class_name = class_obj.name if class_obj else "Unknown"
                
                success = whatsapp_service.send_syllabus_notification(
                    phone_number=staff.phone_no,
                    teacher_name=staff.full_name,
                    class_name=class_name,
                    syllabus_title=syllabus.title
                )
                if success:
                    success_count += 1
                    logger.info(f"Syllabus notification sent to staff: {staff.phone_no}")
            except Exception as e:
                logger.error(f"Exception sending syllabus notification to staff: {str(e)}")
        
        logger.info(f"Syllabus notifications sent to {success_count} staff members")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Exception in send_syllabus_notification: {str(e)}")
        return False


def send_homework_notification(homework: Homework, db: Session) -> bool:
    """
    Send WhatsApp notification to parents when homework is uploaded.
    
    Args:
        homework: The homework object
        db: Database session
        
    Returns:
        True if notification was sent, False otherwise
    """
    try:
        # Get all students in this class
        students = db.query(Student).filter(Student.class_id == homework.class_id).all()
        
        if not students:
            logger.warning(f"No students found in class {homework.class_id}")
            return False
        
        success_count = 0
        
        # Get class name
        from app.models.branch import Class
        class_obj = db.query(Class).filter(Class.id == homework.class_id).first()
        class_name = class_obj.name if class_obj else "Unknown"
        
        # Send notification to parents of all students
        for student in students:
            parent_links = db.query(ParentStudentLink).filter(
                ParentStudentLink.student_id == student.id
            ).all()
            
            for parent_link in parent_links:
                parent_user = db.query(User).filter(User.id == parent_link.user_id).first()
                if not parent_user or not parent_user.phone_no:
                    continue
                
                try:
                    # Format due date if available
                    due_date_str = homework.due_date.strftime("%d-%m-%Y") if homework.due_date else None
                    
                    success = whatsapp_service.send_homework_notification(
                        phone_number=parent_user.phone_no,
                        child_name=student.name,
                        class_name=class_name,
                        homework_title=homework.title,
                        due_date=due_date_str
                    )
                    if success:
                        success_count += 1
                        logger.info(f"Homework notification sent to parent: {parent_user.phone_no}")
                except Exception as e:
                    logger.error(f"Exception sending homework notification: {str(e)}")
        
        logger.info(f"Homework notifications sent to {success_count} parents")
        return success_count > 0
        
    except Exception as e:
        logger.error(f"Exception in send_homework_notification: {str(e)}")
        return False
