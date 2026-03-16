# Fix: index does not exist (migration drop_index errors)

The migration `af3bdb199608` (OneSignal player_id) tries to drop indexes that don't exist on your database (e.g. `ix_daycare_daily_updates_student_date`, `ix_fee_receipts_student_id`).

## Option 1: Run the fix script (if migration file is in repo)

```bash
cd backend
python scripts/fix_onesignal_migration.py
alembic upgrade head
```

## Option 2: Manual edit on server

Edit the migration file and add `, if_exists=True` to **every** `op.drop_index(...)` call:

```bash
nano /root/sunkidz/sunkidz/backend/alembic/versions/af3bdb199608_add_onesignal_player_id_to_user_and_.py
```

Change each line like:
```python
op.drop_index('ix_foo', table_name='bar')
```
To:
```python
op.drop_index('ix_foo', table_name='bar', if_exists=True)
```

Then run:
```bash
alembic upgrade head
```
