#!/bin/bash
# Deployment script for Learning Modules feature
# Run this on the 10.0.0.5 backend server via SSH

set -e

echo "Deploying Learning Modules feature..."

# Navigate to backend directory
cd /root/sunkidz/backend

# Pull latest changes
echo "1. Pulling latest code..."
git pull origin master

# Install dependencies if needed
echo "2. Installing dependencies..."
pip install -q --upgrade -r requirements.txt 2>/dev/null || true

# Stop current backend process
echo "3. Stopping backend..."
pkill -f "python.*main.py" || true
sleep 2

# Run database migration
echo "4. Running database migration..."
python -m alembic upgrade head

# Start backend
echo "5. Starting backend..."
nohup python main.py > app.log 2>&1 &
sleep 3

# Check if backend is running
if curl -s http://localhost:8000/health > /dev/null; then
    echo "✓ Backend is running"
else
    echo "✗ Backend failed to start. Check app.log"
    tail -20 app.log
    exit 1
fi

echo ""
echo "✓ Deployment complete!"
echo "  - Database migration completed"
echo "  - Backend restarted with Learning Modules API"
echo ""
echo "Test the API:"
echo "  curl http://localhost:8000/api/v1/learning-modules/"
