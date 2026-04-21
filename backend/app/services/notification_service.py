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
        
        parent_links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student_id).all()
        subscription_ids = []
        for link in parent_links:
            parent = db.query(User).filter(User.id == link.user_id).first()
            if parent and parent.onesignal_player_id:
                subscription_ids.append(parent.onesignal_player_id)
        
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
        from app.models.branch import BranchAssignment, Class
        class_obj = db.query(Class).filter(Class.id == syllabus.class_id).first()
        class_name = class_obj.name if class_obj else "Class"
        
        staff_assignments = db.query(BranchAssignment).filter(BranchAssignment.class_id == syllabus.class_id).all()
        subscription_ids = []
        for assignment in staff_assignments:
            staff = db.query(User).filter(User.id == assignment.user_id).first()
            if staff and staff.onesignal_player_id:
                subscription_ids.append(staff.onesignal_player_id)
        
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
            links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student.id).all()
            for link in links:
                parent = db.query(User).filter(User.id == link.user_id).first()
                if parent and parent.onesignal_player_id:
                    subscription_ids.append(parent.onesignal_player_id)
        
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

    if not subscription_ids:
        logger.warning("🔔 OneSignal: No subscription IDs provided. Skipping.")
        return False
    
    if not app_id or not api_key:
        logger.error("🔴 CRITICAL: OneSignal credentials NOT configured!")
        logger.error(f"   ONESIGNAL_APP_ID: {'✓ SET' if app_id else '✗ MISSING'}")
        logger.error(f"   ONESIGNAL_API_KEY: {'✓ SET' if api_key else '✗ MISSING'}")
        logger.error("   → Add these to your .env file and restart backend")
        return False

    headers = {
        "Authorization": f"Basic {api_key}",
        "Content-Type": "application/json",
    }

    # OneSignal v5 uses include_subscription_ids; legacy used include_player_ids
    # Only one of these fields should be sent (v5: include_subscription_ids)
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
        
        response = requests.post(ONESIGNAL_API_URL, json=payload, headers=headers, timeout=12)
        
        if response.status_code == 200:
            logger.info("✅ OneSignal push delivered successfully!")
            logger.debug(f"   Response: {response.json()}")
            return True
            
        elif response.status_code == 401:
            logger.error("❌ OneSignal Auth Failed (401) - Invalid credentials")
            logger.error(f"   Response: {response.text}")
            logger.info("🔄 Retrying with 'Key' authorization format...")
            
            headers["Authorization"] = f"Key {api_key}"
            response = requests.post(ONESIGNAL_API_URL, json=payload, headers=headers, timeout=12)
            
            if response.status_code == 200:
                logger.info("✅ Retry successful with 'Key' format!")
                return True
            else:
                logger.error(f"❌ Retry also failed: {response.status_code} - {response.text}")
                return False
        else:
            logger.error(f"❌ OneSignal API Error ({response.status_code})")
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
