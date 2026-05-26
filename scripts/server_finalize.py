"""Stamp alembic + sunkidz rename on server (tables may already exist)."""
import os
import paramiko
import time

PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
B = "/root/sunkidz/sunkidz/backend"
PY = f"{B}/venv/bin/python"

FINALIZE = r"""
import os
os.chdir(%r)
os.environ['PYTHONPATH'] = %r
from dotenv import load_dotenv
from sqlalchemy import create_engine, text, inspect
load_dotenv('.env')
e = create_engine(os.getenv('DATABASE_URL'))
with e.begin() as conn:
    conn.execute(text("UPDATE branches SET system_type = 'sunkidz' WHERE system_type = 'kreedo'"))
    r = conn.execute(text("select distinct system_type from branches")).fetchall()
    print('branch_types', r)
t = inspect(e).get_table_names()
print('has_diary', 'class_diary_entries' in t)
print('has_almanac', 'almanac_events' in t)
from alembic.config import Config
from alembic import command
cfg = Config('alembic.ini')
cfg.set_main_option('script_location', 'alembic')
command.stamp(cfg, '016_class_diary_and_almanac')
print('stamped_016')
""" % (B, B)


def main():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("10.0.0.5", username="root", password=PASSWORD, timeout=25)
    sftp = c.open_sftp()
    with sftp.file(f"{B}/_finalize.py", "w") as f:
        f.write(FINALIZE)
    sftp.close()
    _, o, e = c.exec_command(f"{PY} {B}/_finalize.py 2>&1", timeout=120)
    print((o.read() + e.read()).decode("utf-8", "replace"))
    c.exec_command("pm2 restart sunkidz-api")
    time.sleep(5)
    _, o, _ = c.exec_command("curl -s http://127.0.0.1:8001/health")
    print("health:", o.read().decode())
    c.close()


if __name__ == "__main__":
    main()
