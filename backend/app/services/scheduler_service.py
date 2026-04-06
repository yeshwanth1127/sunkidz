from datetime import datetime, timedelta
import logging
from sqlalchemy.orm import Session
from app.models.fees import FeeStructure, FeePayment
from app.models.student import Student
from app.services.notification_service import send_onesignal_notification
from app.api.admin import _build_fees_detail

logger = logging.getLogger(__name__)

def check_pending_fee_reminders(db: Session):
    """
    Checks for fees due in exactly 2 days and sends reminders.
    Intended to be run once daily.
    """
    logger.info("Starting scheduled fee reminder check...")
    
    # 1. Calculate the target date (2 days from now)
    target_date = (datetime.utcnow() + timedelta(days=2)).date()
    
    # 2. Find all fee structures with this due date
    # We use a broad range for the day to avoid timezone issues
    start_of_target = datetime.combine(target_date, datetime.min.time())
    end_of_target = datetime.combine(target_date, datetime.max.time())
    
    pending_structures = db.query(FeeStructure).filter(
        FeeStructure.due_date >= start_of_target,
        FeeStructure.due_date <= end_of_target
    ).all()
    
    sent_count = 0
    for fs in pending_structures:
        # Avoid sending twice for the same cycle
        # If we sent a reminder in the last 3 days, skip
        if fs.last_reminder_sent_at:
            if (datetime.utcnow() - fs.last_reminder_sent_at).days < 3:
                continue
                
        # 3. Check if balance is actually > 0
        student = db.query(Student).filter(Student.id == fs.student_id).first()
        if not student:
            continue
            
        payments = db.query(FeePayment).filter(FeePayment.student_id == student.id).all()
        fees_detail = _build_fees_detail(student, fs, payments)
        
        balance = fees_detail.get('total_balance', 0.0)
        
        if balance > 0:
            # 4. Find parent user to get player_id
            # In our system, the notification service handles finding the player_id
            # based on student_id for specific triggers. 
            # We'll use a modified call or reuse the existing logic.
            
            try:
                # Custom message for the reminder
                message = f"Reminder: Term fees for {student.name} are due on {fs.due_date.strftime('%d %b %Y')}. Pending balance: ₹{balance}. Please ignore if already paid."
                
                # Use OneSignal to target the parent(s) of this student
                # We can reuse the send_fee_notification logic with a custom message
                _send_custom_fee_reminder(student.id, message, db)
                
                # Update the database to track that we sent it
                fs.last_reminder_sent_at = datetime.utcnow()
                db.commit()
                sent_count += 1
                logger.info(f"Sent fee reminder for student {student.id} (Balance: {balance})")
            except Exception as e:
                logger.error(f"Failed to send reminder for student {student.id}: {str(e)}")
                db.rollback()

    logger.info(f"Finished check. Reminders sent: {sent_count}")
    return sent_count

def _send_custom_fee_reminder(student_id, message, db: Session):
    """Internal helper to target parents of a specific student with a custom message."""
    from app.models.user import User, ParentStudentLink
    
    # Find all parent users linked to this student
    parent_links = db.query(ParentStudentLink).filter(ParentStudentLink.student_id == student_id).all()
    player_ids = []
    
    for link in parent_links:
        user = db.query(User).filter(User.id == link.parent_id).first()
        if user and user.onesignal_player_id:
            player_ids.append(user.onesignal_player_id)
            
    if not player_ids:
        return
        
    send_onesignal_notification(
        player_ids=player_ids,
        heading="Fee Payment Reminder",
        content=message,
        data={"type": "fee_reminder", "student_id": str(student_id)}
    )
