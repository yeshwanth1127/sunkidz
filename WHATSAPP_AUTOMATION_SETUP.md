# WhatsApp Automation Setup - UltraMsg

## Overview
The system now sends a welcome WhatsApp message to parents after they submit an enquiry. We're using **UltraMsg** service for reliable WhatsApp delivery.

## Architecture

```
Enquiry Submission (Mobile/Web)
    ↓
Enquiry API Endpoint (/admin/enquiries - POST)
    ↓
send_enquiry_notification() [notification_service.py]
    ↓
whatsapp_service.send_welcome_message() [whatsapp_service.py]
    ↓
UltraMsg API
    ↓
Parent's WhatsApp Number
```

## Setup Instructions

### 1. Get UltraMsg Credentials

1. Go to [UltraMsg Dashboard](https://ultramsg.com)
2. Sign up or login to your account
3. Create a new WhatsApp instance
4. Copy your:
   - **Instance ID** (e.g., `1234567890abc`)
   - **Auth Token** (long alphanumeric string)

### 2. Configure Environment Variables

Update your `.env` file in the `backend` folder:

```bash
# UltraMsg WhatsApp Configuration
ULTRAMSG_INSTANCE_ID=your_instance_id_here
ULTRAMSG_AUTH_TOKEN=your_auth_token_here
```

Example with real values:
```bash
ULTRAMSG_INSTANCE_ID=1234567890abc
ULTRAMSG_AUTH_TOKEN=abcdef123456789xyz_your_auth_token
```

### 3. Restart the Backend Server

```bash
# Kill the existing server and restart
python -m uvicorn app.main:app --reload
```

## How It Works

### When Enquiry is Submitted:

1. Parent fills out the enquiry form with their contact number (father_contact_no or mother_contact_no)
2. Form is submitted to: `POST /admin/enquiries`
3. Backend:
   - Creates enquiry record in database
   - Triggers `send_enquiry_notification(enquiry)`
   - WhatsApp message is sent asynchronously (non-blocking)

### Message Template

The welcome message sent to parents:

```
Dear Parent,

Thank you for your enquiry at Sunkidz! 🌟

We have received your admission inquiry for [Child Name]. Our team will review the details and get in touch with you shortly.

We look forward to welcoming your child to the Sunkidz family!

Best regards,
Sunkidz Team
```

### Phone Number Logic

- **Priority 1**: Father's contact number (if available)
- **Priority 2**: Mother's contact number (if father's not available)
- **Skip**: If neither parent number is provided
- **Format**: Automatically converts 10-digit numbers to international format (+91 for India)

## Testing

### Using cURL/Postman

```bash
POST /admin/enquiries
Content-Type: application/json

{
  "child_name": "Arjun Kumar",
  "father_contact_no": "9876543210",
  "mother_contact_no": "9876543211",
  "branch_id": "uuid-here",
  "status": "pending"
}
```

### Check Logs

Monitor the backend logs for WhatsApp API responses:

```bash
# Look for these log messages
"Attempting to send WhatsApp message to..."
"WhatsApp message sent successfully to..."
"Failed to send WhatsApp message to..."
```

## Troubleshooting

### Message Not Sent

1. **Check credentials**:
   - Verify `ULTRAMSG_INSTANCE_ID` and `ULTRAMSG_AUTH_TOKEN` are correct
   - Make sure `.env` file is loaded (restart server)

2. **Check phone number format**:
   - Must include country code (India: +91)
   - 10-digit Indian numbers are auto-converted to 91XXXXXXXXXX
   - International numbers need proper country codes

3. **Check logs**:
   - Backend logs show "UltraMsg API returned status X"
   - Status 201/200 = Success
   - Status 4XX = Bad request (check format)
   - Status 5XX = Server error (retry)

### Retry Logic

The system automatically retries failed messages up to 3 times with exponential backoff:
- 1st attempt: Immediate
- 2nd attempt: After 1 second
- 3rd attempt: After 2 seconds
- 4th attempt: After 4 seconds

## API Reference

### Enquiry Creation Endpoint

```
POST /admin/enquiries

Request Body:
{
  "child_name": "string",
  "date_of_birth": "2020-01-15" (optional),
  "age_years": 4 (optional),
  "age_months": 3 (optional),
  "gender": "M|F" (optional),
  "father_name": "string" (optional),
  "father_contact_no": "9876543210" (optional, triggers WhatsApp),
  "mother_name": "string" (optional),
  "mother_contact_no": "9876543210" (optional, triggers WhatsApp),
  "residential_address": "string" (optional),
  "branch_id": "uuid" (optional),
  "status": "pending" (default)
}

Response:
{
  "id": "uuid",
  "child_name": "string",
  "status": "pending",
  "created_at": "ISO-8601 timestamp"
}
```

## Next Steps

- Test with a parent phone number
- Monitor logs for successful delivery
- Customize the welcome message in [whatsapp_service.py](../app/services/whatsapp_service.py) if needed
- Set up message templates for other scenarios (admission confirmation, rejection, etc.)

## Files Modified

- `backend/app/core/config.py` - Updated WhatsApp configuration
- `backend/app/services/whatsapp_service.py` - UltraMsg API integration
- `backend/.env.example` - Updated with UltraMsg credentials template
- `backend/app/services/notification_service.py` - No changes (already set up)
- `backend/app/api/enquiry.py` - No changes (already calls notification service)
