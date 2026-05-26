# Learning Modules Feature - Deployment Instructions

## Prerequisites
- SSH access to 10.0.0.5 (31.97.63.193) backend server
- PostgreSQL access to 10.0.0.1
- WireGuard VPN active (if using external IP)

## Step 1: Deploy Backend Code to 10.0.0.5

Connect via SSH and run these commands:

```bash
cd /root/sunkidz/backend

# Pull latest code
git pull origin master

# Verify the new files exist
ls -la app/api/learning_modules.py
ls -la models/learning_module.py
ls -la alembic/versions/020_learning_modules.py

# Stop the current backend
pkill -f "python.*main.py" || true
sleep 2

# Install requirements (if needed)
pip install -q --upgrade -r requirements.txt

# Run Alembic migration to create database tables
python -m alembic upgrade head

# Start the backend again
nohup python main.py > app.log 2>&1 &

# Wait for startup
sleep 3

# Test the API
curl http://localhost:8000/api/v1/learning-modules/

# Check logs if needed
tail -50 app.log
```

## Step 2: Verify Backend

The API should respond with an empty array:
```json
[]
```

If you see an error, check the app.log file.

## Step 3: Rebuild Mobile App

On your local machine:

```bash
cd d:\sunkidz\mobile

# Clean build
flutter clean

# Get dependencies
flutter pub get

# Run the app
flutter run --release

# Or build for release:
# flutter build apk
# flutter build ios
```

## Step 4: Test the Feature

1. **Login as Admin** to the mobile app
2. **Go to Dashboard** → tap **Learning Modules** (new button in admin section)
3. **Create a Module**: Click "Create Module", enter name and description
4. **Upload Video**: Select the module, click "Upload Video", pick a video file (MP4, MOV, etc. max 50MB)
5. **View as User**: Go to Learning Modules list to see created modules
6. **Play Video**: Tap a module → tap a video → "Play Video" button

## File Changes Summary

### Backend Files Created:
- `backend/app/api/learning_modules.py` - 6 API endpoints
- `backend/app/models/learning_module.py` - Database models
- `backend/alembic/versions/020_learning_modules.py` - Database migration

### Backend Files Modified:
- `backend/app/main.py` - Added router registration
- `backend/app/models/__init__.py` - Added model exports

### Mobile Files Created:
- `mobile/lib/features/learning_modules/data/learning_modules_service.dart`
- `mobile/lib/features/learning_modules/data/learning_modules_provider.dart`
- `mobile/lib/features/learning_modules/presentation/learning_modules_screen.dart`
- `mobile/lib/features/learning_modules/presentation/module_videos_screen.dart`
- `mobile/lib/features/learning_modules/presentation/video_player_screen.dart`
- `mobile/lib/features/learning_modules/presentation/admin_learning_modules_screen.dart`

### Mobile Files Modified:
- `mobile/lib/core/router/app_router.dart` - Added routes
- `mobile/lib/features/dashboard/presentation/admin_dashboard_screen.dart` - Added button

## Troubleshooting

### Backend won't start
```bash
cd /root/sunkidz/backend
python main.py  # Run in foreground to see errors
```

### Migration fails
```bash
# Check current migration status
python -m alembic current

# View migration history
python -m alembic history

# Rollback if needed
python -m alembic downgrade -1
```

### Mobile app still shows error
- Make sure to do a `flutter clean` and full rebuild
- Press `R` (capital) for hot restart, not `r` (lowercase)
- Check the app logs: `flutter logs`

## Git Commits

The changes are already committed:
- `53453d6` - Backend learning modules feature
- `e14ce30` - Mobile learning modules UI

View changes:
```bash
git log --oneline | head -5
git show 53453d6
git show e14ce30
```
