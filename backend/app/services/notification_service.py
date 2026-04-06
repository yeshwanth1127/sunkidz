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


# --- OneSignal Notification ---
ONESIGNAL_APP_ID = settings.onesignal_app_id
ONESIGNAL_API_KEY = settings.onesignal_api_key
# OneSignal REST API (supports both v1 and newer - use include_subscription_ids for OneSignal v5)
ONESIGNAL_API_URL = "https://api.onesignal.com/notifications"


def send_onesignal_notification(subscription_ids: list[str], title: str, message: str) -> bool:
    """Send push via OneSignal. subscription_ids can be subscription IDs (v5) or player IDs (legacy)."""
    if not subscription_ids or not ONESIGNAL_APP_ID or not ONESIGNAL_API_KEY:
        return False
    headers = {
        "Authorization": f"Key {ONESIGNAL_API_KEY}",
        "Content-Type": "application/json",
    }
    # OneSignal v5 uses include_subscription_ids; legacy used include_player_ids
    payload = {
        "app_id": ONESIGNAL_APP_ID,
        "include_subscription_ids": subscription_ids,
        "headings": {"en": title},
        "contents": {"en": message},
    }
    try:
        response = requests.post(ONESIGNAL_API_URL, json=payload, headers=headers, timeout=10)
        if response.status_code != 200:
            logger.warning(f"OneSignal API error: {response.status_code} {response.text}")
        return response.status_code == 200
    except Exception as e:
        logger.error(f"OneSignal send failed: {e}")
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
