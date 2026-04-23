#!/usr/bin/env python3
"""
Fix migrations that fail when dropping non-existent indexes.
Adds if_exists=True to all op.drop_index() calls in the af3bdb/onesignal migration.
Run on the server before 'alembic upgrade head'.

Usage:
  cd backend && python scripts/fix_onesignal_migration.py
"""
import glob
import os
import re

versions_dir = os.path.join(os.path.dirname(__file__), "..", "alembic", "versions")
files = sorted(glob.glob(os.path.join(versions_dir, "*.py")))
# Only fix the af3bdb/onesignal migration (the one that fails on server)
files = [f for f in files if "onesignal" in f.lower() or "af3bdb" in f]

for path in files:
    with open(path, "r") as f:
        content = f.read()

    if "op.drop_index(" not in content:
        continue

    # Add if_exists=True to op.drop_index('name', table_name='table') - simple format only
    # Avoids op.drop_index(op.f(...), ...) which has nested parens
    def add_if_exists(match):
        s = match.group(0)
        if "if_exists" in s or "op.f(" in s:
            return s
        return s[:-1] + ", if_exists=True)"

    content_new = re.sub(
        r"op\.drop_index\('[^']+',\s*table_name='[^']+'\)",
        add_if_exists,
        content,
    )
    content_new = re.sub(
        r'op\.drop_index\("[^"]+",\s*table_name="[^"]+"\)',
        add_if_exists,
        content_new,
    )
    if content_new != content:
        with open(path, "w") as f:
            f.write(content_new)
        print(f"Fixed: {path}")
        exit(0)

print("No migrations needed fixing. If still failing, manually add if_exists=True to each")
print("op.drop_index(...) in alembic/versions/af3bdb199608_add_onesignal_player_id_to_user_and_.py")
