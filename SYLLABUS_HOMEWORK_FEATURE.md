# Syllabus and Homework Management Feature

## Overview
This feature allows administrators and teachers to upload and manage syllabus and homework assignments for different classes/grades with day-wise organization.

## Features Implemented

### Backend (Python/FastAPI)
1. **Database Models** (`backend/app/models/syllabus.py`)
   - `Syllabus` model: Stores syllabus files with grade and date information
   - `Homework` model: Stores homework files with grade, date, and due date information

2. **API Endpoints** (`backend/app/api/syllabus.py`)
   - Syllabus endpoints:
     - `POST /api/v1/syllabus/upload` - Upload syllabus
     - `GET /api/v1/syllabus` - List syllabus (with filters)
     - `GET /api/v1/syllabus/{id}` - Get specific syllabus
     - `PUT /api/v1/syllabus/{id}` - Update syllabus metadata
     - `DELETE /api/v1/syllabus/{id}` - Delete syllabus
   
   - Homework endpoints:
     - `POST /api/v1/homework/upload` - Upload homework
     - `GET /api/v1/homework` - List homework (with filters)
     - `GET /api/v1/homework/{id}` - Get specific homework
     - `PUT /api/v1/homework/{id}` - Update homework metadata
     - `DELETE /api/v1/homework/{id}` - Delete homework

3. **Role-Based Access Control**
   - **Admin**: Can upload syllabus/homework for any grade, view all, and delete
   - **Teachers**: Can upload homework for their assigned grade only, view syllabus for their grade
   - **Coordinators**: Can view all uploaded syllabus and homework

4. **File Upload Handling**
   - Files are stored in `backend/uploads/syllabus/` and `backend/uploads/homework/`
   - Supports PDF, DOC, DOCX, JPG, JPEG, PNG formats
   - Automatic file size calculation

### Frontend (Flutter)
1. **Screens**
   - `SyllabusListScreen`: View and filter syllabus by class and date
   - `SyllabusUploadScreen`: Upload new syllabus files
   - `HomeworkListScreen`: View and filter homework by class and date
   - `HomeworkUploadScreen`: Upload new homework assignments

2. **Navigation**
   - Added to admin drawer with icons
   - Routes: `/syllabus` and `/homework`

3. **Features**
   - File picker integration for document uploads
   - Date picker for upload date and due date selection
   - Class/grade dropdown selector
   - Filter by class and date
   - Delete functionality (admin only)

## Setup Instructions

### 1. Backend Setup

#### Run Database Migration
```bash
cd backend
alembic upgrade head
```

This will create the `syllabus` and `homework` tables in the database.

#### Create Upload Directories
The directories will be created automatically when the application runs, but you can create them manually:
```bash
mkdir -p uploads/syllabus
mkdir -p uploads/homework
```

#### Restart the Backend Server
```bash
python -m uvicorn app.main:app --reload
```

### 2. Frontend Setup

#### Install Dependencies
```bash
cd mobile
flutter pub get
```

#### Full Restart Required
After adding new routes, you must do a **FULL RESTART** (stop app + flutter run) or press `R` for hot restart. Hot reload (`r`) does NOT pick up route changes.

```bash
flutter run
```

## Usage Guide

### For Administrators
1. Login as admin
2. Navigate to "Syllabus" or "Homework" from the drawer menu
3. Use the filters to view by class or date
4. Click the "+" button to upload new files
5. Select class, enter title, choose date, and pick a file
6. Upload and the file will be available to teachers and coordinators

### For Teachers
1. Login as teacher
2. Navigate to "Homework" to upload homework for your assigned class
3. View syllabus uploaded by admin for your class
4. Filter by date to see daily syllabus/homework

### For Coordinators
1. Login as coordinator
2. View all syllabus and homework uploaded by admin
3. Filter by class and date to see specific content

## File Structure

### Backend
```
backend/
├── app/
│   ├── api/
│   │   └── syllabus.py          # API endpoints
│   ├── models/
│   │   └── syllabus.py          # Database models
│   ├── schemas/
│   │   └── syllabus.py          # Pydantic schemas
│   └── main.py                  # Updated with new router
├── alembic/
│   └── versions/
│       └── 003_syllabus_homework.py  # Migration file
└── uploads/                     # File storage (auto-created)
    ├── syllabus/
    └── homework/
```

### Frontend
```
mobile/
├── lib/
│   ├── core/
│   │   └── router/
│   │       └── app_router.dart  # Updated with new routes
│   ├── features/
│   │   └── syllabus/
│   │       ├── data/
│   │       │   └── syllabus_service.dart      # API service
│   │       ├── domain/
│   │       │   └── models/
│   │       │       └── syllabus_model.dart    # Models
│   │       ├── presentation/
│   │       │   ├── syllabus_list_screen.dart
│   │       │   ├── syllabus_upload_screen.dart
│   │       │   ├── homework_list_screen.dart
│   │       │   └── homework_upload_screen.dart
│   │       └── providers/
│   │           └── syllabus_provider.dart     # State management
│   └── shared/
│       └── widgets/
│           └── admin_drawer.dart              # Updated with new menu items
└── pubspec.yaml                               # Updated with file_picker dependency
```

## Testing Checklist

### Backend Testing
- [ ] Run migration successfully
- [ ] Test syllabus upload as admin
- [ ] Test homework upload as teacher
- [ ] Test unauthorized access (teacher uploading to wrong class)
- [ ] Test file retrieval
- [ ] Test filtering by class and date
- [ ] Test delete functionality

### Frontend Testing
- [ ] Open syllabus list screen
- [ ] Upload syllabus file
- [ ] Filter by class
- [ ] Filter by date
- [ ] Open homework list screen
- [ ] Upload homework file
- [ ] Delete syllabus/homework
- [ ] Verify file picker works
- [ ] Verify date picker works

## Future Enhancements
1. Add file viewing/download functionality
2. Add notifications when new homework is assigned
3. Add support for multiple file uploads
4. Add homework submission feature for students/parents
5. Add analytics for syllabus coverage
6. Add ability to edit uploaded files

## Notes
- Supported file formats: PDF, DOC, DOCX, JPG, JPEG, PNG
- Files are stored with UUID-based names to prevent conflicts
- File size is automatically calculated and displayed
- Coordinators can only view, not upload
- Teachers can only upload homework for their assigned classes
- Admin has full access to all features
