#!/bin/bash
# Copy entire script and paste into SSH terminal connected to 10.0.0.5

cd /root/sunkidz/backend && git pull origin master && python -m alembic upgrade head && pkill -f "python.*main.py" 2>/dev/null; sleep 2; nohup python main.py > app.log 2>&1 & sleep 3 && echo "✓ Deployment complete" && curl http://localhost:8000/api/v1/learning-modules/ && echo ""
