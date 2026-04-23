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
import requests

from app.models.notification import Notification
from app.schemas.notification import NotificationCreate

from app.core.config import settings

logger = logging.getLogger(__name__)


def send_enquiry_notification(enquiry: Enquiry, db: Session) -> bool:
    """Notify admins when a new enquiry is submitted via OneSignal push."""
    try:
        title = "New Student Enquiry! 🎒"
        message = f"New enquiry received for {enquiry.child_name} ({enquiry.gender or 'not specified'})."
        
        # Get all admins to notify
        admins = db.query(User).filter(User.role == "admin", User.is_active == "true").all()
        subscription_ids = [a.onesignal_player_id for a in admins if a.onesignal_player_id]
        
        if subscription_ids:
            return send_onesignal_notification(subscription_ids, title, message)
        return False
    except Exception as e:
        logger.error(f"Error in send_enquiry_notification: {e}")
        return False


def send_fee_notification(student_id: UUID, db: Session) -> bool:
    """Send push notification to parents when fee structure is updated."""
    try:
        student = db.query(Student).filter(Student.id == student_id).first()
        if not student: return False
        
<<<<<<< HEAD
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
            if not parent_user or not parent_user.phone:
                logger.warning(f"Parent {parent_link.user_id} has no phone number")
                continue
            
            try:
                success = whatsapp_service.send_fee_notification(
                    phone_number=parent_user.phone,
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
=======
        parent_links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student_id).all()
        subscription_ids = []
        for link in parent_links:
            parent = db.query(User).filter(User.id == link.user_id).first()
            if parent and parent.onesignal_player_id:
                subscription_ids.append(parent.onesignal_player_id)
>>>>>>> ac1ff0b
        
        if subscription_ids:
            title = "Fee Structure Update 💰"
            message = f"The fee structure for {student.name} has been updated. Please check the app for details."
            return send_onesignal_notification(subscription_ids, title, message)
        return False
    except Exception as e:
        logger.error(f"Error in send_fee_notification: {e}")
        return False


def send_syllabus_notification(syllabus: Syllabus, db: Session) -> bool:
    """Notify staff when a new syllabus is uploaded."""
    try:
<<<<<<< HEAD
        # Get all staff (teachers and coordinators) in the class
        from app.models.branch import BranchAssignment, Class

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
            if not staff or not staff.phone:
                continue
            
            try:
                # Get class name
                from app.models.branch import Class
                class_obj = db.query(Class).filter(Class.id == syllabus.class_id).first()
                class_name = class_obj.name if class_obj else "Unknown"
                
                success = whatsapp_service.send_syllabus_notification(
                    phone_number=staff.phone,
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
=======
        from app.models.branch import BranchAssignment, Class
        class_obj = db.query(Class).filter(Class.id == syllabus.class_id).first()
        class_name = class_obj.name if class_obj else "Class"
        
        staff_assignments = db.query(BranchAssignment).filter(BranchAssignment.class_id == syllabus.class_id).all()
        subscription_ids = []
        for assignment in staff_assignments:
            staff = db.query(User).filter(User.id == assignment.user_id).first()
            if staff and staff.onesignal_player_id:
                subscription_ids.append(staff.onesignal_player_id)
>>>>>>> ac1ff0b
        
        if subscription_ids:
            title = f"New Syllabus: {class_name} 📚"
            message = f"A new syllabus '{syllabus.title}' has been uploaded."
            return send_onesignal_notification(subscription_ids, title, message)
        return False
    except Exception as e:
        logger.error(f"Error in send_syllabus_notification: {e}")
        return False


def send_homework_notification(homework: Homework, db: Session) -> bool:
    """Notify parents when new homework is assigned."""
    try:
        from app.models.branch import Class
        class_obj = db.query(Class).filter(Class.id == homework.class_id).first()
        class_name = class_obj.name if class_obj else "Class"
        
        students = db.query(Student).filter(Student.class_id == homework.class_id).all()
        subscription_ids = []
        for student in students:
<<<<<<< HEAD
            parent_links = db.query(ParentStudentLink).filter(
                ParentStudentLink.student_id == student.id
            ).all()
            
            for parent_link in parent_links:
                parent_user = db.query(User).filter(User.id == parent_link.user_id).first()
                if not parent_user or not parent_user.phone:
                    continue
                
                try:
                    # Format due date if available
                    due_date_str = homework.due_date.strftime("%d-%m-%Y") if homework.due_date else None
                    
                    success = whatsapp_service.send_homework_notification(
                        phone_number=parent_user.phone,
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
=======
            links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student.id).all()
            for link in links:
                parent = db.query(User).filter(User.id == link.user_id).first()
                if parent and parent.onesignal_player_id:
                    subscription_ids.append(parent.onesignal_player_id)
>>>>>>> ac1ff0b
        
        if subscription_ids:
            title = f"New Homework! ✏️ ({class_name})"
            message = f"Homework '{homework.title}' has been assigned. Please check the student portal."
            return send_onesignal_notification(subscription_ids, title, message)
        return False
    except Exception as e:
        logger.error(f"Error in send_homework_notification: {e}")
        return False


def send_fee_receipt_notification(student_id: UUID, payment, fees_detail: dict, db: Session) -> bool:
    """Notify parents after a fee payment is recorded."""
    try:
        student = db.query(Student).filter(Student.id == student_id).first()
        if not student: return False
        
        parent_links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student_id).all()
        subscription_ids = []
        for link in parent_links:
            parent = db.query(User).filter(User.id == link.user_id).first()
            if parent and parent.onesignal_player_id:
                subscription_ids.append(parent.onesignal_player_id)
        
        if subscription_ids:
            amount_paid = float(payment.amount_paid or 0.0)
            title = "Fee Payment Received 🙏"
            message = f"Payment of ₹{amount_paid:,.2f} for {student.name} has been processed successfully."
            return send_onesignal_notification(subscription_ids, title, message)
        return False
    except Exception as e:
        logger.error(f"Error in send_fee_receipt_notification: {e}")
        return False


# OneSignal REST API URL
ONESIGNAL_API_URL = "https://api.onesignal.com/notifications"


def send_onesignal_notification(
    subscription_ids: list[str], title: str, message: str, data: dict | None = None
) -> bool:
    """Send push via OneSignal using modern v5 compatible payload and logging."""
    app_id = settings.onesignal_app_id
    api_key = settings.onesignal_api_key

    subscription_ids = [sid.strip() for sid in (subscription_ids or []) if sid and sid.strip()]

    if not subscription_ids:
        logger.warning("🔔 OneSignal: No subscription IDs provided. Skipping.")
        return False
    
    if not app_id or not api_key:
        logger.error("🔴 CRITICAL: OneSignal credentials NOT configured!")
        logger.error(f"   ONESIGNAL_APP_ID: {'✓ SET' if app_id else '✗ MISSING'}")
        logger.error(f"   ONESIGNAL_API_KEY: {'✓ SET' if api_key else '✗ MISSING'}")
        logger.error("   → Add these to your .env file and restart backend")
        return False

    # OneSignal v5 uses include_subscription_ids; legacy used include_player_ids
    # Only one of these fields should be sent (v5: include_subscription_ids).
    payload = {
        "app_id": app_id,
        "include_subscription_ids": subscription_ids,
        "headings": {"en": title},
        "contents": {"en": message},
    }
    
    if data:
        payload["data"] = data

    try:
        logger.info(f"📤 OneSignal: Sending to {len(subscription_ids)} device(s)")
        logger.debug(f"   • Title: {title}")
        logger.debug(f"   • Message: {message}")
        logger.debug(f"   • Sample IDs: {subscription_ids[:3]}")
        
        auth_attempts = [
            ("Key", f"Key {api_key}"),
            ("Basic", f"Basic {api_key}"),
        ]
        for idx, (label, auth_header) in enumerate(auth_attempts):
            headers = {
                "Authorization": auth_header,
                "Content-Type": "application/json",
            }
            response = requests.post(ONESIGNAL_API_URL, json=payload, headers=headers, timeout=12)
            if response.status_code == 200:
                logger.info(f"✅ OneSignal push delivered successfully using {label} auth")
                logger.debug(f"   Response: {response.json()}")
                return True

            if response.status_code in (401, 403) and idx < len(auth_attempts) - 1:
                logger.warning(f"⚠️ OneSignal auth rejected ({response.status_code}) using {label}, retrying alternate format")
                logger.warning(f"   Response: {response.text}")
                continue

            logger.error(f"❌ OneSignal API Error ({response.status_code}) with {label} auth")
            logger.error(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"❌ OneSignal request exception: {e}")
        import traceback
        logger.error(f"   Traceback: {traceback.format_exc()}")
        return False


def push_admin_notification(db: Session, admin_user_id: UUID, title: str, message: str, related_enquiry_id: UUID | None = None):
    # Create DB notification
    notification = Notification(
        user_id=admin_user_id,
        title=title,
        message=message,
        related_enquiry_id=related_enquiry_id,
        is_read=False
    )
    db.add(notification)
    db.commit()
    db.refresh(notification)
    # Send OneSignal push
    admin = db.query(User).filter(User.id == admin_user_id).first()
    if admin and admin.onesignal_player_id:
        send_onesignal_notification([admin.onesignal_player_id], title, message)  # stored subscription_id
    return notification
