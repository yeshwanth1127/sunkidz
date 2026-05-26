# Fix Production Backend for Learning Modules

## Issue
- Web/Mobile app at `https://api.sunkidz.org` returns CORS error when uploading videos
- Error: `No 'Access-Control-Allow-Origin' header is present`

## Root Cause
Production backend code hasn't been updated with:
1. Learning Modules API (`app/api/learning_modules.py`)
2. Learning Modules models (`app/models/learning_module.py`)
3. Database migration (`alembic/versions/020_learning_modules.py`)
4. Router registration in `app/main.py` (line 80)

## Fix - Deploy to Production (31.97.63.193)

SSH into production server and run:

```bash
cd /root/sunkidz/backend

# 1. Pull latest code with Learning Modules feature
git pull origin master

# 2. Stop current backend
pkill -f "python.*main.py" || true
sleep 2

# 3. Install dependencies
pip install -q --upgrade -r requirements.txt

# 4. Run database migration to create learning_module and learning_video tables
python -m alembic upgrade heads

# 5. Start backend with CORS enabled
nohup python main.py > app.log 2>&1 &
sleep 3

# 6. Verify backend is running
curl -s http://localhost:8001/api/v1/learning-modules/
# Should return: []

# 7. Check logs if needed
tail -50 app.log
```

## What Gets Fixed
✓ CORS headers will be sent (allow_origins=["*"])
✓ POST `/learning-modules/{module_id}/videos/upload` will accept video uploads
✓ Videos will be saved to `uploads/learning-videos/`
✓ Database records created in `learning_video` table

## Test After Deployment
1. Go to https://www.sunkidz.org/#/admin
2. Click "Learning Modules" button
3. Create a new module
4. Upload a video - should work without CORS error
5. Video should appear in module list

## Credentials
- Backend server: 31.97.63.193 (also accessible via 93.127.195.245)
- Database: same server, port 5432, user: sunkidz_user
- Backend port: 8001 (internal) / 443 (external via api.sunkidz.org)
