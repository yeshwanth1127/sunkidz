# Daily Repertory Feature Plan

## Overview

A "Daily Repertory" is a structured daily schedule report created by staff (admin / coordinator / teacher) for a specific class on a specific date. Each report contains time-slot rows, each with a timing and a description. Once ready, the creator can send it to all parents of that class as a push notification.

---

## User Flow

```
Admin / Coordinator / Teacher Dashboard
  └─ "Daily Repertory" button
       └─ GradeListScreen — cards for every class/grade
            └─ tap a grade
                 └─ ReportScreen(classId, className, date)
                      ├─ Date picker to navigate between days
                      ├─ If no report yet: empty state + "Create Report" button
                      ├─ If report exists: editable list of time-slot rows
                      │    ┌────────────────┬────────────────────────────────┐
                      │    │  Timing        │  Description                   │
                      │    │  8:00–9:00 AM  │  Morning assembly & prayer     │
                      │    │  9:00–10:00 AM │  English – Chapter 3 reading   │
                      │    │  …             │  …                             │
                      │    └────────────────┴────────────────────────────────┘
                      ├─ "+ Add Row" button
                      ├─ "Save" button
                      └─ "Send to Parents" button (disabled until saved)
```

Parent sees a read-only view of the same report in their dashboard (future scope — no new parent screen needed now; push notification carries the content).

---

## Data Model

### `daily_repertory` table

| Column            | Type         | Notes                                             |
|-------------------|--------------|---------------------------------------------------|
| `id`              | String(36)   | UUID primary key                                  |
| `class_id`        | String(36)   | Which class this report belongs to                |
| `report_date`     | Date         | The school date this report covers                |
| `created_by`      | String(36)   | User ID of creator                                |
| `created_at`      | DateTime     | Auto timestamp                                    |
| `updated_at`      | DateTime     | Auto-updated on save                              |
| `sent_to_parents` | Boolean      | Whether notification has been sent, default False |
| `sent_at`         | DateTime     | Nullable — when it was sent                       |

**Unique constraint:** `(class_id, report_date)` — one report per class per day.

### `daily_repertory_slot` table

| Column        | Type         | Notes                                          |
|---------------|--------------|------------------------------------------------|
| `id`          | String(36)   | UUID primary key                               |
| `repertory_id`| String(36)   | FK → `daily_repertory.id` (cascade delete)     |
| `timing`      | String(100)  | e.g. "8:00 AM – 9:00 AM"                       |
| `description` | String(2000) | What happened / what is planned                |
| `slot_order`  | Integer      | Display order (0-based)                        |

---

## Backend Changes

### 1. Migration — `027_daily_repertory.py`

```
revision = "027_daily_repertory"
down_revision = "026_day_folders"
```

Creates both tables with:
- Index on `(class_id, report_date)` for fast day-lookup
- Index on `repertory_id` in slots table
- Unique constraint `uq_repertory_class_date` on `(class_id, report_date)`
- FK with `ondelete="CASCADE"` from slots → repertory

### 2. Models — `backend/app/models/daily_repertory.py` (new file)

```python
from uuid import uuid4
from sqlalchemy import Column, String, DateTime, Date, Boolean, Integer, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base


class DailyRepertory(Base):
    __tablename__ = "daily_repertory"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    class_id = Column(String(36), nullable=False)
    report_date = Column(Date, nullable=False)
    created_by = Column(String(36), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    sent_to_parents = Column(Boolean, default=False, nullable=False)
    sent_at = Column(DateTime, nullable=True)

    slots = relationship(
        "DailyRepertorySlot",
        back_populates="repertory",
        cascade="all, delete-orphan",
        order_by="DailyRepertorySlot.slot_order",
    )

    __table_args__ = (
        UniqueConstraint("class_id", "report_date", name="uq_repertory_class_date"),
    )


class DailyRepertorySlot(Base):
    __tablename__ = "daily_repertory_slot"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid4()))
    repertory_id = Column(
        String(36), ForeignKey("daily_repertory.id", ondelete="CASCADE"), nullable=False
    )
    timing = Column(String(100), nullable=False)
    description = Column(String(2000), nullable=True)
    slot_order = Column(Integer, nullable=False, default=0)

    repertory = relationship("DailyRepertory", back_populates="slots")
```

Export both from `app/models/__init__.py`.

### 3. API Endpoints — `backend/app/api/daily_repertory.py` (new file)

Register in `app/main.py` as:
```python
from app.api import daily_repertory
app.include_router(daily_repertory.router, prefix="/api/v1")
```

#### Get report for a class on a date
```
GET /daily-repertory/?class_id=&date=YYYY-MM-DD
Auth: get_current_user (any role)
Returns: report object with slots, or null if none exists for that date
```

Response shape:
```json
{
  "id": "...",
  "class_id": "...",
  "report_date": "2025-06-10",
  "created_by": "...",
  "sent_to_parents": false,
  "sent_at": null,
  "updated_at": "...",
  "slots": [
    { "id": "...", "timing": "8:00–9:00 AM", "description": "Morning assembly", "slot_order": 0 }
  ]
}
```

Returns `null` (HTTP 200 with `{}` body or a 404 if preferred) when no report exists.

#### Create a report with slots
```
POST /daily-repertory/
Auth: admin, coordinator, or teacher assigned to this class
Body (JSON):
{
  "class_id": "...",
  "report_date": "2025-06-10",
  "slots": [
    { "timing": "8:00–9:00 AM", "description": "Morning assembly", "slot_order": 0 },
    ...
  ]
}
Validation: 409 Conflict if a report already exists for (class_id, report_date)
Returns: full report with slots
```

#### Update a report (replace all slots)
```
PUT /daily-repertory/{report_id}
Auth: creator, or admin/coordinator
Body (JSON):
{
  "slots": [
    { "timing": "...", "description": "...", "slot_order": 0 },
    ...
  ]
}
Logic: delete all existing slots for this report, re-insert from request body
Returns: updated report with slots
```

#### Delete a report
```
DELETE /daily-repertory/{report_id}
Auth: admin or coordinator only
Returns: { "message": "Report deleted" }
```

#### Send report to all parents of the class
```
POST /daily-repertory/{report_id}/send-to-parents
Auth: admin, coordinator, or teacher assigned to class
Logic:
  1. Load report + class info
  2. Query all students where student.class_id == class_id
  3. Query ParentStudentLink for those student IDs → collect parent user IDs (deduplicated)
  4. For each parent: build notification title + message body (formatted slot list)
  5. Call create_notifications_for_users(db, user_ids, title, message)
  6. Set report.sent_to_parents = True, report.sent_at = now()
  7. Return { "message": "Sent to {n} parents" }
```

Notification format:
- Title: `"Daily Repertory – {class_name} ({date})"`
- Body: First 3 slots joined as `"8:00–9:00 AM: Morning assembly\n9:00–10:00 AM: English…"` (truncated to 250 chars + "…")

#### List recent reports for a class (optional, for history)
```
GET /daily-repertory/history?class_id=&limit=10
Auth: get_current_user
Returns: list of { id, report_date, sent_to_parents, slot_count }
```

### 4. Authorization Logic

Teachers can only create/edit reports for classes they are assigned to. Check via:
```python
assignment = db.query(BranchAssignment).filter(
    BranchAssignment.user_id == current_user.id,
    BranchAssignment.class_id == class_id
).first()
if not assignment:
    raise HTTPException(403, "You are not assigned to this class")
```
Admins and coordinators bypass this check.

---

## Frontend Plan (guide only — you implement)

### New Files

```
mobile/lib/features/daily_repertory/
  data/
    daily_repertory_service.dart     # API calls (get, create, update, delete, send)
    daily_repertory_provider.dart    # Riverpod FutureProvider.family keyed by (classId, date)
  presentation/
    grade_list_screen.dart           # Grid of class cards — first screen after tapping button
    repertory_report_screen.dart     # The time-slot report editor for a specific class+date
```

### Service Methods (`daily_repertory_service.dart`)

```dart
// Get the report for a class on a date (returns null if none)
Future<Map<String, dynamic>?> getReport(String classId, String date);

// Create a new report with slots
Future<Map<String, dynamic>> createReport(String classId, String date, List<Map<String, dynamic>> slots);

// Update slots (replaces all existing)
Future<Map<String, dynamic>> updateReport(String reportId, List<Map<String, dynamic>> slots);

// Delete a report
Future<void> deleteReport(String reportId);

// Send push notification to all parents
Future<Map<String, dynamic>> sendToParents(String reportId);
```

### Provider (`daily_repertory_provider.dart`)

```dart
// Keyed by (classId, dateString) — e.g. ("abc-123", "2025-06-10")
final repertoryProvider = FutureProvider.family<Map<String, dynamic>?, (String, String)>((ref, args) async {
  ...
});
```

### `grade_list_screen.dart`

- **AppBar:** "Daily Repertory"
- **Body:** fetch all classes the current user has access to (reuse existing admin/teacher class-list providers)
- **Display:** `GridView` of class cards (class name + branch name + today's repertory status badge — "Sent" in green, "Draft" in orange, "None" in grey)
- **Tap:** navigate to `RepertoryReportScreen(classId: ..., className: ...)`
- **Auth:** admins/coordinators see all classes; teachers see only their assigned classes

### `repertory_report_screen.dart`

- **AppBar:** class name + date (e.g. "Grade 3A — 10 Jun 2025")
- **Date navigation:** left/right arrow buttons in app bar to move between days
- **Body:**
  - If loading → `CircularProgressIndicator`
  - If no report → empty state with "No report for this day" + "Create Report" button
  - If report exists → `ListView` of slot rows
- **Slot row layout:**
  ```
  ┌──────────────────────┬────────────────────────────────────────┐
  │  [Timing TextField]  │  [Description TextField (multiline)]   │
  │  e.g. 8:00–9:00 AM   │                                        │
  └──────────────────────┴────────────────────────────────────────┘
  [drag handle to reorder]  [delete icon]
  ```
- **"+ Add Row"** button at the bottom of the list
- **Bottom bar** (sticky):
  - "Save" button → `createReport()` or `updateReport()` depending on whether report exists
  - "Send to Parents" button (green, disabled until saved, shows "Sent ✓" after sending)
- **Confirmation dialog** before Send to Parents: "This will notify all parents of {className}. Proceed?"

### Dashboard Integration

Add "Daily Repertory" button/card to:
- `admin_dashboard_screen.dart` — add to the "Content & Learning" section alongside "Learning Modules"
- `coordinator_dashboard_screen.dart` — same section
- `teacher_dashboard_screen.dart` — prominent button since this is their primary daily task

Route: `context.push('/admin/daily-repertory')` (or `/teacher/`, `/coordinator/`)

### Routes to Register in `app_router.dart`

```dart
// Under /admin
GoRoute(path: 'daily-repertory', builder: (_, __) => const GradeListScreen()),

// Under /coordinator
GoRoute(path: 'daily-repertory', builder: (_, __) => const GradeListScreen()),

// Under /teacher
GoRoute(path: 'daily-repertory', builder: (_, __) => const GradeListScreen()),
```

`RepertoryReportScreen` is pushed via `context.push()` from `GradeListScreen` with `extra: {classId, className}` — no separate route needed.

---

## Implementation Order

### Backend (implement first)
- [ ] Create `027_daily_repertory.py` migration
- [ ] Create `backend/app/models/daily_repertory.py`
- [ ] Export `DailyRepertory`, `DailyRepertorySlot` from `models/__init__.py`
- [ ] Create `backend/app/api/daily_repertory.py` with all 6 endpoints
- [ ] Register router in `app/main.py`
- [ ] Run migration, test endpoints with curl

### Frontend (you implement)
- [ ] `daily_repertory_service.dart` — 5 service methods
- [ ] `daily_repertory_provider.dart` — FutureProvider.family
- [ ] `grade_list_screen.dart` — class grid
- [ ] `repertory_report_screen.dart` — report editor + send button
- [ ] Add button to admin / coordinator / teacher dashboards
- [ ] Register routes in `app_router.dart`

---

## Key Design Decisions

- **One report per class per day** (unique constraint) — no versioning needed; staff edit the single draft and send when ready.
- **Slots are fully replaced on update** — simpler than individual slot PATCH endpoints; the client always sends the full ordered list.
- **Notification body is text-only** — the formatted timing list in the push body is enough; parents can open the app to see the full report (future: parent read screen).
- **`sent_to_parents` is a one-way flag** — once sent, the button shows "Sent ✓" and is disabled. If the report is edited after sending, a new "Re-send" option could be added later.
- **Teacher access is class-scoped** — teachers only see and edit reports for their assigned classes, enforced at the API level.
- **No separate parent endpoint needed now** — parents receive the full content via push notification; a dedicated parent reading screen is a future iteration.
