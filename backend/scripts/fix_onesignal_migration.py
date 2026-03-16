#!/usr/bin/env python3
"""
Fix the af3bdb199608 migration that fails when dropping a non-existent index.
Run this on the server before 'alembic upgrade head'.

Usage:
  cd backend && python scripts/fix_onesignal_migration.py
"""
import glob
import os

versions_dir = os.path.join(os.path.dirname(__file__), "..", "alembic", "versions")
files = sorted(glob.glob(os.path.join(versions_dir, "*.py")))
# Prefer onesignal/af3bdb migration (the one that fails)
files = [f for f in files if "onesignal" in f.lower() or "af3bdb" in f] + [f for f in files if "onesignal" not in f.lower() and "af3bdb" not in f]

for path in files:
    with open(path, "r") as f:
        content = f.read()

    replacements = [
        ("op.drop_index('ix_daycare_daily_updates_student_date', table_name='daycare_daily_updates')",
         "op.drop_index('ix_daycare_daily_updates_student_date', table_name='daycare_daily_updates', if_exists=True)"),
        ('op.drop_index("ix_daycare_daily_updates_student_date", table_name="daycare_daily_updates")',
         'op.drop_index("ix_daycare_daily_updates_student_date", table_name="daycare_daily_updates", if_exists=True)'),
    ]

    modified = False
    for old, new in replacements:
        if old in content and new not in content:
            content = content.replace(old, new)
            modified = True
    if modified:
        with open(path, "w") as f:
            f.write(content)
        print(f"Fixed: {path}")
        exit(0)
    if 'if_exists=True' in content and 'ix_daycare_daily_updates_student_date' in content:
        print(f"Already fixed: {path}")
        exit(0)

else:
    print("No migration with that drop_index found. Manually edit on your server:")
    print("  alembic/versions/af3bdb199608_add_onesignal_player_id_to_user_and_.py")
    print("Change:")
    print("  op.drop_index('ix_daycare_daily_updates_student_date', table_name='daycare_daily_updates')")
    print("To:")
    print("  op.drop_index('ix_daycare_daily_updates_student_date', table_name='daycare_daily_updates', if_exists=True)")
