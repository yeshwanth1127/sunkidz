# Day Folder Feature Plan
## Learning Module: Day → Folder → Content Flow

### Overview

When an admin clicks on a specific school day in the learning module calendar, a new screen opens where they can:
1. Create named folders for that day
2. Open a folder to see its contents
3. Upload videos or documents with a title and description into that folder

This replaces the current flat "videos per day" model with a structured folder hierarchy per day.

---

## Current System (Context)

- `LearningModule` groups videos, assigned to a class or branch
- `LearningVideo` has `school_day` (int 1–180) and `academic_year_start` (Date)
- `GET /learning-modules/class-calendar?class_id=&academic_year=` returns Day 1–180 with videos per day
- Admin currently uploads videos directly tied to a school day via `POST /learning-modules/class-upload`

---

## New Data Model

### `DayFolder` table

| Column              | Type        | Notes                                          |
|---------------------|-------------|------------------------------------------------|
| `id`                | String(36)  | UUID primary key                               |
| `name`              | String(255) | Folder name, e.g. "Math Notes", "Science Lab"  |
| `class_id`          | String(36)  | Which class this folder belongs to             |
| `school_day`        | Integer     | Day number (1–180)                             |
| `academic_year_start` | Date      | e.g. 2025-06-01                                |
| `created_by`        | String(36)  | Admin user ID                                  |
| `created_at`        | DateTime    | Auto timestamp                                 |
| `updated_at`        | DateTime    | Auto-updated on change                         |

Unique constraint: `(class_id, school_day, academic_year_start, name)`

### `DayFolderContent` table

| Column         | Type        | Notes                                     |
|----------------|-------------|-------------------------------------------|
| `id`           | String(36)  | UUID primary key                          |
| `folder_id`    | String(36)  | FK → `day_folder.id` (cascade delete)     |
| `title`        | String(255) | Content title                             |
| `description`  | String(1000)| Optional description                      |
| `file_path`    | String(500) | Server file path                          |
| `file_name`    | String(255) | Original file name                        |
| `file_size`    | Integer     | Bytes                                     |
| `content_type` | String(20)  | `"video"` or `"document"`                 |
| `created_at`   | DateTime    | Auto timestamp                            |

---

## Backend Changes

### 1. Migration — `024_day_folders.py`

```
revision = "024_day_folders"
down_revision = "023_learning_video_fields"  (or latest migration)
```

Creates `day_folder` and `day_folder_content` tables with indexes on `(class_id, school_day, academic_year_start)` and FK from content to folder.

### 2. Model — `backend/app/models/learning_module.py`

Add two new SQLAlchemy classes alongside the existing ones:

```python
class DayFolder(Base):
    __tablename__ = "day_folder"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    name = Column(String(255), nullable=False)
    class_id = Column(String(36), nullable=False)
    school_day = Column(Integer, nullable=False)
    academic_year_start = Column(Date, nullable=False)
    created_by = Column(String(36), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    contents = relationship("DayFolderContent", back_populates="folder", cascade="all, delete-orphan")


class DayFolderContent(Base):
    __tablename__ = "day_folder_content"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    folder_id = Column(String(36), ForeignKey("day_folder.id"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(String(1000), nullable=True)
    file_path = Column(String(500), nullable=False)
    file_name = Column(String(255), nullable=False)
    file_size = Column(Integer, nullable=False)
    content_type = Column(String(20), nullable=False)  # "video" or "document"
    created_at = Column(DateTime, default=datetime.utcnow)

    folder = relationship("DayFolder", back_populates="contents")
```

Export both from `app/models/__init__.py`.

### 3. New API Endpoints — `backend/app/api/learning_modules.py`

#### List folders for a day
```
GET /learning-modules/day-folders
  Query params: class_id (required), school_day (required), academic_year (optional, int year)
  Auth: get_current_user (admin, coordinator, teacher who owns the class)
  Returns: list of { id, name, class_id, school_day, content_count }
```

#### Create a folder
```
POST /learning-modules/day-folders
  Form: class_id, school_day, name, academic_year_start (optional, default current year)
  Auth: require_admin
  Returns: { id, name, class_id, school_day, academic_year_start, created_at }
  Validation: unique name per (class_id, school_day, academic_year_start)
```

#### Delete a folder (cascades to all contents)
```
DELETE /learning-modules/day-folders/{folder_id}
  Auth: require_admin
  Returns: { message: "Folder deleted" }
```

#### List contents inside a folder
```
GET /learning-modules/day-folders/{folder_id}/contents
  Auth: get_current_user
  Returns: list of { id, title, description, file_path, file_name, file_size, content_type, created_at }
```

#### Upload content into a folder
```
POST /learning-modules/day-folders/{folder_id}/upload
  Form: title, description (optional), file (UploadFile)
  Auth: require_admin
  Logic:
    - Detect content_type from file extension using media_kind_for_filename()
    - Save via save_upload_file() to "uploads/day-folder-contents/"
    - Validate file_size >= MIN_VIDEO_BYTES for videos
    - Store DayFolderContent record
  Returns: { id, folder_id, title, description, file_name, content_type, created_at }
```

#### Delete content
```
DELETE /learning-modules/day-folder-contents/{content_id}
  Auth: require_admin
  Returns: { message: "Content deleted" }
```

#### Updated class-calendar response
Extend the existing `GET /learning-modules/class-calendar` to also return `folder_count` per day:

```json
{
  "days": [
    {
      "day": 3,
      "date": "2025-06-04",
      "videos": [...],
      "folder_count": 2
    }
  ]
}
```

This lets the UI show a badge on days that have folders.

---

## Frontend (Flutter) Changes

### New Files

```
mobile/lib/features/learning_modules/presentation/
  day_detail_screen.dart          # Folder list for a day
  folder_contents_screen.dart     # Contents inside a folder
  create_folder_dialog.dart       # Dialog to create a folder
  upload_content_dialog.dart      # Dialog to upload video/document
```

### Updated Files

```
mobile/lib/features/learning_modules/data/
  learning_modules_service.dart   # Add 5 new service methods
  learning_modules_provider.dart  # Add 2 new providers
```

---

### Screen Flow

```
AdminLearningModulesScreen
  └─ (tap class calendar day)
      └─ DayDetailScreen(classId, schoolDay, date, academicYear)
           ├─ FAB "+" → CreateFolderDialog → POST day-folders
           └─ FolderCard (tap)
                └─ FolderContentsScreen(folderId, folderName)
                     ├─ FAB "+" → UploadContentDialog → POST day-folders/{id}/upload
                     ├─ VideoContentTile (tap) → VideoPlayerScreen
                     └─ DocumentContentTile (tap) → open/download
```

---

### `DayDetailScreen`

- **Route:** `/admin/learning-modules/day/:classId/:schoolDay`
- **AppBar title:** "Day {schoolDay} — {date}"
- **Body:** `FutureProvider` watching `dayFoldersProvider(classId, schoolDay, academicYear)`
  - Loading → `CircularProgressIndicator`
  - Empty → "No folders yet. Tap + to create one."
  - List → `ListView` of `_FolderCard` widgets
- **FAB:** Opens `CreateFolderDialog`
- Each `_FolderCard`:
  - Folder icon + name
  - Subtitle: "{n} items"
  - Long-press or swipe → delete (admin only)
  - Tap → navigate to `FolderContentsScreen`

### `CreateFolderDialog`

- Text field: "Folder Name" (required)
- Cancel / Create buttons
- On Create: calls `service.createDayFolder(classId, schoolDay, name, academicYearStart)`
- Refreshes `dayFoldersProvider` on success

### `FolderContentsScreen`

- **Route:** `/admin/learning-modules/folder/:folderId`
- **AppBar title:** folder name
- **Body:** `FutureProvider` watching `folderContentsProvider(folderId)`
  - Shows list of content items grouped or sorted by type
  - Each item shows: thumbnail/icon, title, description, file type badge
  - Swipe or long-press → delete (admin only)
- **FAB:** Opens `UploadContentDialog`

### `UploadContentDialog`

```
Title:       [Text field — required]
Description: [Text field — optional, multiline]
File:        [Pick File button — allows video + document types]
             Shows selected file name once picked
Upload / Cancel buttons
```

- `FilePicker.platform.pickFiles(type: FileType.any)` — accepts videos and documents
- Sends multipart form to `POST /learning-modules/day-folders/{folderId}/upload`
- Shows `CircularProgressIndicator` during upload
- Refreshes `folderContentsProvider` on success

---

### New Service Methods (`learning_modules_service.dart`)

```dart
Future<List<Map<String, dynamic>>> getDayFolders(String classId, int schoolDay, String academicYearStart);

Future<Map<String, dynamic>> createDayFolder(String classId, int schoolDay, String name, String academicYearStart);

Future<void> deleteDayFolder(String folderId);

Future<List<Map<String, dynamic>>> getFolderContents(String folderId);

Future<Map<String, dynamic>> uploadFolderContent(String folderId, PlatformFile file, String title, String? description);

Future<void> deleteFolderContent(String contentId);
```

### New Providers (`learning_modules_provider.dart`)

```dart
// Family provider keyed by (classId, schoolDay, academicYearStart)
final dayFoldersProvider = FutureProvider.family<List<Map<String, dynamic>>, (String, int, String)>(...);

// Family provider keyed by folderId
final folderContentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(...);
```

---

## Migration File (024)

```python
revision = "024_day_folders"
down_revision = "023_learning_video_fields"

def upgrade():
    op.create_table(
        'day_folder',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('class_id', sa.String(36), nullable=False),
        sa.Column('school_day', sa.Integer(), nullable=False),
        sa.Column('academic_year_start', sa.Date(), nullable=False),
        sa.Column('created_by', sa.String(36), nullable=False),
        sa.Column('created_at', sa.DateTime()),
        sa.Column('updated_at', sa.DateTime()),
        sa.UniqueConstraint('class_id', 'school_day', 'academic_year_start', 'name',
                            name='uq_day_folder_name'),
    )
    op.create_index('ix_day_folder_class_day', 'day_folder',
                    ['class_id', 'school_day', 'academic_year_start'])

    op.create_table(
        'day_folder_content',
        sa.Column('id', sa.String(36), primary_key=True),
        sa.Column('folder_id', sa.String(36), sa.ForeignKey('day_folder.id'), nullable=False),
        sa.Column('title', sa.String(255), nullable=False),
        sa.Column('description', sa.String(1000), nullable=True),
        sa.Column('file_path', sa.String(500), nullable=False),
        sa.Column('file_name', sa.String(255), nullable=False),
        sa.Column('file_size', sa.Integer(), nullable=False),
        sa.Column('content_type', sa.String(20), nullable=False),
        sa.Column('created_at', sa.DateTime()),
    )
    op.create_index('ix_day_folder_content_folder', 'day_folder_content', ['folder_id'])

def downgrade():
    op.drop_table('day_folder_content')
    op.drop_table('day_folder')
```

---

## Implementation Order

1. **Backend first**
   - [ ] Write migration `024_day_folders.py`
   - [ ] Add `DayFolder` and `DayFolderContent` models to `learning_module.py`
   - [ ] Export from `models/__init__.py`
   - [ ] Add 6 new endpoints to `learning_modules.py`
   - [ ] Extend `class-calendar` response to include `folder_count`
   - [ ] Run migration locally, test with curl

2. **Flutter service + providers**
   - [ ] Add 6 methods to `learning_modules_service.dart`
   - [ ] Add `dayFoldersProvider` and `folderContentsProvider` to `learning_modules_provider.dart`

3. **Flutter screens**
   - [ ] `create_folder_dialog.dart`
   - [ ] `day_detail_screen.dart`
   - [ ] `upload_content_dialog.dart`
   - [ ] `folder_contents_screen.dart`
   - [ ] Wire navigation: day tap in calendar → `DayDetailScreen`
   - [ ] Register new routes in router

4. **Deploy**
   - [ ] Run alembic migration on production
   - [ ] Restart backend
   - [ ] Build and test Flutter app

---

## Key Design Decisions

- **Folders are per class + school day + academic year** — not per module. This avoids the complexity of the module assignment system for the new flow. Internally they are independent of `LearningModule` / `LearningVideo`.
- **Content type auto-detected** from file extension using the existing `media_kind_for_filename()` utility.
- **Both videos and documents allowed** — file picker uses `FileType.any` with no extension filter; backend validates and stores `content_type` as `"video"` or `"document"`.
- **Cascade delete** — deleting a folder removes all its contents from the DB (file cleanup on disk is a future improvement or handled by existing delete logic).
- **Existing calendar API extended** — only `folder_count` is added to the response so existing functionality is not broken.
- **No changes to `LearningModule` or `LearningVideo`** — the old direct-upload flow is preserved; folders are an additive feature.
