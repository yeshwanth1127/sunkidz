"""
WhatsApp Business API service for sending messages via Meta Cloud API.
"""

import logging
import time
import requests
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)


class WhatsAppService:
    """Service for interacting with WhatsApp Business API."""
    
    BASE_URL = "https://graph.facebook.com/v18.0"
    MAX_RETRIES = 3
    RETRY_DELAYS = [1, 2, 4]  # Exponential backoff in seconds
    
    def __init__(self):
        self.api_token = settings.whatsapp_api_token
        self.phone_number_id = settings.whatsapp_phone_number_id
        self.business_account_id = settings.whatsapp_business_account_id
        
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
        Make a single API request to send WhatsApp message.
        
        Args:
            phone_number: Formatted phone number with country code
            message: Message content to send
            
        Returns:
            True if successful, False otherwise
        """
        if not self.api_token or not self.phone_number_id:
            logger.error("WhatsApp API credentials not configured")
            return False
        
        url = f"{self.BASE_URL}/{self.phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {self.api_token}",
            "Content-Type": "application/json"
        }
        payload = {
            "messaging_product": "whatsapp",
            "to": phone_number,
            "type": "text",
            "text": {
                "body": message
            }
        }
        
        try:
            response = requests.post(url, json=payload, headers=headers, timeout=10)
            
            if response.status_code == 200:
                logger.info(f"WhatsApp message sent successfully to {phone_number}")
                return True
            else:
                logger.warning(
                    f"WhatsApp API returned status {response.status_code} for {phone_number}: {response.text}"
                )
                return False
                
        except requests.exceptions.Timeout:
            logger.error(f"WhatsApp API request timeout for {phone_number}")
            return False
        except requests.exceptions.RequestException as e:
            logger.error(f"WhatsApp API request failed for {phone_number}: {str(e)}")
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


# Singleton instance
whatsapp_service = WhatsAppService()
