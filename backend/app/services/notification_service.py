"""
Notification service for handling enquiry notifications.
"""

import logging
from typing import Optional

from app.models.enquiry import Enquiry
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
