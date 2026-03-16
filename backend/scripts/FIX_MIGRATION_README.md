# Fix: index "ix_daycare_daily_updates_student_date" does not exist

The migration `af3bdb199608` (OneSignal player_id) tries to drop an index that doesn't exist on your database.

## Option 1: Run the fix script (if migration file is in repo)

```bash
cd backend
python scripts/fix_onesignal_migration.py
alembic upgrade head
```

## Option 2: Manual edit on server

Edit the migration file on your server:

```bash
nano /root/sunkidz/sunkidz/backend/alembic/versions/af3bdb199608_add_onesignal_player_id_to_user_and_.py
```

Find this line:
```python
op.drop_index('ix_daycare_daily_updates_student_date', table_name='daycare_daily_updates')
```

Change it to:
```python
op.drop_index('ix_daycare_daily_updates_student_date', table_name='daycare_daily_updates', if_exists=True)
```

Then run:
```bash
alembic upgrade head
```

## Option 3: sed one-liner on server

```bash
cd /root/sunkidz/sunkidz/backend
sed -i "s/op.drop_index('ix_daycare_daily_updates_student_date', table_name='daycare_daily_updates')/op.drop_index('ix_daycare_daily_updates_student_date', table_name='daycare_daily_updates', if_exists=True)/" alembic/versions/af3bdb199608_add_onesignal_player_id_to_user_and_.py
alembic upgrade head
```
