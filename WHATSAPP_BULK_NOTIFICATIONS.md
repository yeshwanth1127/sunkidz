# WhatsApp Bulk Notifications Implementation

## Overview

WhatsApp notifications have been implemented for 4 key scenarios:

1. ✅ **Enquiry Welcome Message** - Sent to parent after enquiry submission
2. ✅ **Fee Notification** - Sent to parents when fee structure is setup/updated
3. ✅ **Syllabus Notification** - Sent to staff when syllabus is uploaded
4. ✅ **Homework Notification** - Sent to all parents in the class when homework is uploaded

All notifications are sent via **UltraMsg** WhatsApp API.

---

## Architecture

```
API Endpoint Triggered
    ↓
Record Created/Updated in Database
    ↓
Notification Function Called (Non-blocking)
    ↓
Query Parents/Staff Phone Numbers
    ↓
Send WhatsApp Message via UltraMsg
    ↓
Retry Logic (Max 3 attempts with exponential backoff)
```

---

## Implementation Details

### 1. Enquiry Welcome Message

**Endpoint:** `POST /admin/enquiries`

**What happens:**
- Parent submits enquiry form with child name and phone number
- Backend creates enquiry record
- Automatic WhatsApp message sent to parent's number (father's priority, then mother's)

**Message Template:**
```
Dear Parent,

Thank you for your enquiry at Sunkidz! 🌟

We have received your admission inquiry for [Child Name]. Our team will review the details and get in touch with you shortly.

We look forward to welcoming your child to the Sunkidz family!

Best regards,
Sunkidz Team
```

**Code Location:** 
- [backend/app/api/enquiry.py](backend/app/api/enquiry.py) - Line where `send_enquiry_notification()` is called
- [backend/app/services/notification_service.py](backend/app/services/notification_service.py) - `send_enquiry_notification()` function

---

### 2. Fee Setup/Update Notification

**Endpoint:** `PUT /admin/students/{student_id}/fees`

**What happens:**
- Admin sets up or updates fee structure for a student
- WhatsApp messages sent to all parents linked to that student
- Parents notified about fee structure update

**Message Template:**
```
Dear Parent,

The fee structure for [Child Name] has been updated in Sunkidz system.

Please log in to the parent portal to view the complete fee breakdown and payment details.

If you have any questions regarding the fees, please contact the school office.

Best regards,
Sunkidz Management
```

**Code Location:**
- [backend/app/api/admin.py](backend/app/api/admin.py) - `upsert_student_fees()` endpoint (calls `send_fee_notification()`)
- [backend/app/services/notification_service.py](backend/app/services/notification_service.py) - `send_fee_notification()` function

**Phone Number Source:** `User.phone_no` field from parent user profile

---

### 3. Syllabus Upload Notification

**Endpoint:** `POST /syllabus/upload`

**What happens:**
- Admin/Teacher uploads syllabus for a class
- WhatsApp messages sent to all staff (teachers/coordinators) assigned to that class
- Staff notified about new syllabus availability

**Message Template:**
```
Dear [Teacher Name],

A new syllabus has been uploaded for class [Class Name]:

📚 [Syllabus Title]

Please check the Sunkidz portal for more details.

Best regards,
Sunkidz System
```

**Code Location:**
- [backend/app/api/syllabus.py](backend/app/api/syllabus.py) - `upload_syllabus()` endpoint (calls `send_syllabus_notification()`)
- [backend/app/services/notification_service.py](backend/app/services/notification_service.py) - `send_syllabus_notification()` function

**Recipients:** All staff assigned to the class via `BranchAssignment` table

**Phone Number Source:** `User.phone_no` field from teacher/coordinator user profile

---

### 4. Homework Upload Notification

**Endpoint:** `POST /homework/upload`

**What happens:**
- Teacher/Admin uploads homework for a class
- WhatsApp messages sent to all parents of students in that class
- Parents notified about new homework with optional due date

**Message Template:**
```
Dear Parent,

A new homework assignment has been posted for [Child Name] ([Class Name]):

✏️ [Homework Title]
📅 Due Date: [Due Date] (if available)

Please log in to the parent portal to view the complete assignment.

Best regards,
Sunkidz Team
```

**Code Location:**
- [backend/app/api/syllabus.py](backend/app/api/syllabus.py) - `upload_homework()` endpoint (calls `send_homework_notification()`)
- [backend/app/services/notification_service.py](backend/app/services/notification_service.py) - `send_homework_notification()` function

**Recipients:** All parents of students in the class
- Query: `Student` → `ParentStudentLink` → `User`

**Phone Number Source:** `User.phone_no` field from parent user profile

---

## WhatsApp Service Architecture

**File:** [backend/app/services/whatsapp_service.py](backend/app/services/whatsapp_service.py)

**Key Methods:**

1. `send_welcome_message(phone_number, child_name)` → Enquiry welcome
2. `send_fee_notification(phone_number, student_name, child_name)` → Fee update
3. `send_syllabus_notification(phone_number, teacher_name, class_name, syllabus_title)` → Syllabus upload
4. `send_homework_notification(phone_number, child_name, class_name, homework_title, due_date)` → Homework upload

**Features:**
- Automatic phone number formatting (converts 10-digit Indian numbers to 91-prefixed format)
- Automatic retry logic (max 3 attempts with exponential backoff: 1s, 2s, 4s)
- Comprehensive error logging
- Non-blocking message delivery

---

## Configuration

**File:** [backend/.env](backend/.env)

Required settings:
```bash
# UltraMsg WhatsApp Configuration
ULTRAMSG_API_URL=https://api.ultramsg.com
ULTRAMSG_INSTANCE_ID=your_instance_id_here
ULTRAMSG_AUTH_TOKEN=your_auth_token_here
```

**How to get credentials:**
1. Visit https://ultramsg.com
2. Sign up/login
3. Create a WhatsApp instance
4. Copy Instance ID and Auth Token from dashboard
5. Update .env file with your credentials

---

## Phone Number Requirements

### For Parents
- Must have `phone_no` field populated in `User` table
- This is used for all parent notifications (fees, homework)
- Used as fallback if enquiry contact numbers not available

### For Teachers/Staff
- Must have `phone_no` field populated in `User` table
- Used for syllabus upload notifications

### For Enquiry
- Parent must provide contact number during enquiry form submission
- Priority: Father's number → Mother's number
- If neither provided, message silently fails (logged as warning)

---

## Database Fields Used

### User Model
- `phone_no` - Contact number for notifications

### Student Model
- `class_id` - Used to identify students per class (for homework)
- `name` - Child name for personalization

### ParentStudentLink Model
- Links parents to students for notification targeting

### BranchAssignment Model
- Links staff to classes for syllabus notification targeting

### Enquiry Model
- `father_contact_no` / `mother_contact_no` - Enquiry contact numbers
- `child_name` - Child name for welcome message

---

## Testing

### 1. Test Enquiry Welcome Message

```bash
POST /admin/enquiries
Content-Type: application/json

{
  "child_name": "Test Child",
  "father_contact_no": "9876543210",  # Will be converted to 919876543210
  "branch_id": "uuid-here"
}
```

Check logs:
```
INFO: Attempting to send WhatsApp message to 919876543210 for child: Test Child
INFO: WhatsApp message sent successfully to 919876543210
```

---

### 2. Test Fee Notification

```bash
PUT /admin/students/{student_id}/fees
Content-Type: application/json

{
  "advance_fees": 50000,
  "term_fee_1": 25000,
  "term_fee_2": 25000,
  "term_fee_3": 25000
}
```

Check logs:
```
INFO: Fee notifications sent to X/Y parents
INFO: Fee notification sent to parent: 919876543210
```

---

### 3. Test Syllabus Upload Notification

```bash
POST /syllabus/upload
Content-Type: multipart/form-data

Form fields:
- class_id: uuid
- title: "Mathematics Chapter 5"
- upload_date: "2024-03-09"
- description: "Trigonometry basics"
- file: [syllabus file]
```

Check logs:
```
INFO: Syllabus notifications sent to X staff members
INFO: Syllabus notification sent to staff: 919876543210
```

---

### 4. Test Homework Upload Notification

```bash
POST /homework/upload
Content-Type: multipart/form-data

Form fields:
- class_id: uuid
- title: "Chapter 5 Exercises"
- upload_date: "2024-03-09"
- due_date: "2024-03-16"
- description: "Complete all exercises"
- file: [homework file]
```

Check logs:
```
INFO: Homework notifications sent to X parents
INFO: Homework notification sent to parent: 919876543210
```

---

## Logs Location

All WhatsApp notifications are logged. See logs in your terminal/logging system:

```
# Look for these patterns in logs:
"Attempting to send WhatsApp message"
"WhatsApp message sent successfully"
"Failed to send WhatsApp message"
"Fee notification sent to parent"
"Syllabus notification sent to staff"
"Homework notification sent to parent"
```

---

## Files Modified

1. ✅ `backend/app/services/whatsapp_service.py` - Added 3 new message methods
2. ✅ `backend/app/services/notification_service.py` - Added 3 new notification functions
3. ✅ `backend/app/api/admin.py` - Added fee notification call
4. ✅ `backend/app/api/syllabus.py` - Added syllabus & homework notification calls
5. ✅ `backend/app/core/config.py` - Added UltraMsg config (API URL, Instance ID, Token)
6. ✅ `backend/.env` - UltraMsg credentials

---

## Error Handling

All notifications are non-blocking:
- If notification fails, API response is not affected
- Messages are retried up to 3 times automatically
- Failures are logged but don't stop the main operation
- Parents/Staff are not charged if message fails

```python
# Example from code
try:
    send_fee_notification(student_id, db)
except Exception as ex:
    logger.error(f"Failed to send fee notification: {str(ex)}")
    # API continues normally
```

---

## Next Steps / Future Enhancements

1. **Scheduled Bulk Messages** - Send bulk messages to specific groups on schedule
2. **Media Attachments** - Send documents/images with messages
3. **Message Templates** - Create reusable message templates via UltraMsg API
4. **Delivery Status Tracking** - Track message delivery status and store in database
5. **Two-way Messaging** - Receive and process parent replies
6. **Custom Message Builders** - Allow admin to customize message content

---

## Support

For issues:
1. Check `.env` credentials are correct
2. Verify UltraMsg account is active and has balance
3. Verify user phone numbers are stored with country codes
4. Check backend logs for detailed error messages
5. Test with direct UltraMsg API call using cURL/Postman

---

## Troubleshooting

### Messages Not Sending

**Check 1: Credentials**
```bash
# Verify in .env
ULTRAMSG_INSTANCE_ID=check_value
ULTRAMSG_AUTH_TOKEN=check_value
```

**Check 2: Phone Numbers**
- Ensure phone numbers include country code (91 for India)
- Format: `919876543210` or `+919876543210`

**Check 3: UltraMsg Account**
- Visit https://ultramsg.com and verify account is active
- Check you have sufficient balance/credits

**Check 4: Logs**
```bash
# Check backend logs for detailed error messages
tail -f backend.log | grep -i whatsapp
```

---

## API Response Examples

### Enquiry Response (includes notification attempt)
```json
{
  "id": "uuid",
  "child_name": "Test Child",
  "status": "pending",
  "created_at": "2024-03-09T10:30:00Z"
  // Notification sent in background
}
```

### Fee Response (includes notification attempt)
```json
{
  "id": "uuid",
  "student_id": "uuid",
  "advance_fees": 50000,
  "term_fee_1": 25000,
  // Notification sent to parents in background
}
```

### Syllabus Response (includes notification attempt)
```json
{
  "id": "uuid",
  "class_id": "uuid",
  "title": "Mathematics Chapter 5",
  // Notification sent to staff in background
}
```

### Homework Response (includes notification attempt)
```json
{
  "id": "uuid",
  "class_id": "uuid",
  "title": "Chapter 5 Exercises",
  "due_date": "2024-03-16",
  // Notification sent to parents in background
}
```

---

## Summary

You now have fully automated WhatsApp notifications for:
- ✅ New enquiries
- ✅ Fee updates
- ✅ Syllabus uploads
- ✅ Homework uploads

Just ensure your users have phone numbers in their profiles, and the system will handle the rest automatically!
