"""
WhatsApp service for sending messages via UltraMsg API.
"""

import logging
import time
import requests
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)


class WhatsAppService:
    """Service for interacting with UltraMsg WhatsApp API."""
    
    MAX_RETRIES = 3
    RETRY_DELAYS = [1, 2, 4]  # Exponential backoff in seconds
    
    def __init__(self):
        self.api_url = settings.ultramsg_api_url
        self.instance_id = settings.ultramsg_instance_id
        self.auth_token = settings.ultramsg_auth_token
        
    def _format_phone_number(self, phone: str) -> str:
        """
        Format phone number to international format.
        Assumes Indian numbers (+91) if not already prefixed.
        
        Args:
            phone: Phone number (can include spaces, hyphens, or +91 prefix)
            
        Returns:
            Formatted phone number with country code (no + prefix for API)
        """
        # Remove all spaces, hyphens, and parentheses
        cleaned = phone.replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
        
        # Remove leading + if present
        if cleaned.startswith("+"):
            cleaned = cleaned[1:]
        
        # Add country code if not present (assume India)
        if not cleaned.startswith("91") and len(cleaned) == 10:
            cleaned = "91" + cleaned
            
        return cleaned
    
    def _build_message(self, child_name: str) -> str:
        """
        Build the WhatsApp message content.
        
        Args:
            child_name: Name of the child from the enquiry
            
        Returns:
            Formatted message string
        """
        return f"""Dear Parent,

Thank you for your enquiry at Sunkidz! 🌟

We have received your admission inquiry for {child_name}. Our team will review the details and get in touch with you shortly.

We look forward to welcoming your child to the Sunkidz family!

Best regards,
Sunkidz Team"""
    
    def _send_message_request(self, phone_number: str, message: str) -> bool:
        """
        Make a single API request to send WhatsApp message via UltraMsg.
        
        Args:
            phone_number: Formatted phone number with country code
            message: Message content to send
            
        Returns:
            True if successful, False otherwise
        """
        if not self.instance_id or not self.auth_token:
            logger.error("UltraMsg credentials not configured")
            return False
        
        url = f"{self.api_url}/{self.instance_id}/messages/chat"
        params = {
            "token": self.auth_token
        }
        payload = {
            "phone": phone_number,
            "body": message
        }
        
        try:
            response = requests.post(url, json=payload, params=params, timeout=10)
            
            if response.status_code == 200:
                logger.info(f"WhatsApp message sent successfully to {phone_number}")
                return True
            else:
                logger.warning(
                    f"UltraMsg API returned status {response.status_code} for {phone_number}: {response.text}"
                )
                return False
                
        except requests.exceptions.Timeout:
            logger.error(f"UltraMsg API request timeout for {phone_number}")
            return False
        except requests.exceptions.RequestException as e:
            logger.error(f"UltraMsg API request failed for {phone_number}: {str(e)}")
            return False
    
    def send_welcome_message(self, phone_number: str, child_name: str) -> bool:
        """
        Send a welcome message to the parent via WhatsApp with retry logic.
        
        Args:
            phone_number: Phone number to send the message to
            child_name: Name of the child for personalization
            
        Returns:
            True if message was sent successfully (within retry attempts), False otherwise
        """
        if not phone_number:
            logger.warning("No phone number provided for WhatsApp message")
            return False
        
        formatted_phone = self._format_phone_number(phone_number)
        message = self._build_message(child_name)
        
        logger.info(f"Attempting to send WhatsApp message to {formatted_phone} for child: {child_name}")
        
        # Try sending with retry logic
        for attempt in range(self.MAX_RETRIES):
            if attempt > 0:
                delay = self.RETRY_DELAYS[attempt - 1]
                logger.info(f"Retry attempt {attempt + 1}/{self.MAX_RETRIES} after {delay}s delay")
                time.sleep(delay)
            
            success = self._send_message_request(formatted_phone, message)
            
            if success:
                return True
        
        logger.error(
            f"Failed to send WhatsApp message to {formatted_phone} after {self.MAX_RETRIES} attempts"
        )
        return False
    
    def send_fee_notification(self, phone_number: str, student_name: str, child_name: str) -> bool:
        """
        Send fee setup/update notification to parent.
        
        Args:
            phone_number: Parent's phone number
            student_name: Student's name
            child_name: Child's name (for personalization)
            
        Returns:
            True if successful, False otherwise
        """
        if not phone_number:
            logger.warning("No phone number provided for fee notification")
            return False
        
        formatted_phone = self._format_phone_number(phone_number)
        message = f"""Dear Parent,

The fee structure for {child_name} has been updated in Sunkidz system.

Please log in to the parent portal to view the complete fee breakdown and payment details.

If you have any questions regarding the fees, please contact the school office.

Best regards,
Sunkidz Management"""
        
        logger.info(f"Attempting to send fee notification to {formatted_phone} for {child_name}")
        
        # Try sending with retry logic
        for attempt in range(self.MAX_RETRIES):
            if attempt > 0:
                delay = self.RETRY_DELAYS[attempt - 1]
                time.sleep(delay)
            
            success = self._send_message_request(formatted_phone, message)
            
            if success:
                return True
        
        return False
    
    def send_syllabus_notification(self, phone_number: str, teacher_name: str, class_name: str, syllabus_title: str) -> bool:
        """
        Send syllabus upload notification to staff.
        
        Args:
            phone_number: Staff member's phone number
            teacher_name: Staff member's name
            class_name: Class name
            syllabus_title: Title of the uploaded syllabus
            
        Returns:
            True if successful, False otherwise
        """
        if not phone_number:
            logger.warning("No phone number provided for syllabus notification")
            return False
        
        formatted_phone = self._format_phone_number(phone_number)
        message = f"""Dear {teacher_name},

A new syllabus has been uploaded for class {class_name}:

📚 {syllabus_title}

Please check the Sunkidz portal for more details.

Best regards,
Sunkidz System"""
        
        logger.info(f"Attempting to send syllabus notification to {formatted_phone}")
        
        # Try sending with retry logic
        for attempt in range(self.MAX_RETRIES):
            if attempt > 0:
                delay = self.RETRY_DELAYS[attempt - 1]
                time.sleep(delay)
            
            success = self._send_message_request(formatted_phone, message)
            
            if success:
                return True
        
        return False
    
    def send_homework_notification(self, phone_number: str, child_name: str, class_name: str, homework_title: str, due_date: Optional[str] = None) -> bool:
        """
        Send homework upload notification to parent.
        
        Args:
            phone_number: Parent's phone number
            child_name: Child's name
            class_name: Class name
            homework_title: Title of the homework
            due_date: Due date (if available)
            
        Returns:
            True if successful, False otherwise
        """
        if not phone_number:
            logger.warning("No phone number provided for homework notification")
            return False
        
        formatted_phone = self._format_phone_number(phone_number)
        
        due_info = f"\n📅 Due Date: {due_date}" if due_date else ""
        message = f"""Dear Parent,

A new homework assignment has been posted for {child_name} ({class_name}):

✏️ {homework_title}{due_info}

Please log in to the parent portal to view the complete assignment.

Best regards,
Sunkidz Team"""
        
        logger.info(f"Attempting to send homework notification to {formatted_phone} for {child_name}")
        
        # Try sending with retry logic
        for attempt in range(self.MAX_RETRIES):
            if attempt > 0:
                delay = self.RETRY_DELAYS[attempt - 1]
                time.sleep(delay)
            
            success = self._send_message_request(formatted_phone, message)
            
            if success:
                return True
        
        return False


# Singleton instance
whatsapp_service = WhatsAppService()
