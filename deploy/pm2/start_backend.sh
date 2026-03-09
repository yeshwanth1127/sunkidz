#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/var/www/sunkidz/backend"
cd "$PROJECT_DIR"

if [[ -f "$PROJECT_DIR/.env" ]]; then
  set -a
  # Load runtime environment variables (DATABASE_URL, JWT, etc.)
  . "$PROJECT_DIR/.env"
  set +a
fi

if [[ -x "$PROJECT_DIR/.venv/bin/python" ]]; then
  PYTHON_BIN="$PROJECT_DIR/.venv/bin/python"
elif [[ -x "$PROJECT_DIR/venv/bin/python" ]]; then
  PYTHON_BIN="$PROJECT_DIR/venv/bin/python"
else
  PYTHON_BIN="python3"
fi

exec "$PYTHON_BIN" -m uvicorn app.main:app --host 127.0.0.1 --port 9889 --workers 2
