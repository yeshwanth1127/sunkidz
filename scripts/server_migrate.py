"""Run alembic on server via venv python."""
import os
import paramiko
import time

PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
B = "/root/sunkidz/sunkidz/backend"
PY = f"{B}/venv/bin/python"

MIGRATE_PY = r"""
import os
os.chdir(%r)
os.environ.setdefault('PYTHONPATH', %r)
from alembic.config import Config
from alembic import command
cfg = Config('alembic.ini')
cfg.set_main_option('script_location', 'alembic')
command.upgrade(cfg, 'head')
print('MIGRATION_OK')
""" % (
    B,
    B,
)


def run(client, cmd):
    _, o, e = client.exec_command(cmd, timeout=180)
    return (o.read() + e.read()).decode("utf-8", "replace")


def main():
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("10.0.0.5", username="root", password=PASSWORD, timeout=25)
    # Write temp script and run
    sftp = c.open_sftp()
    with sftp.file(f"{B}/_run_migrate.py", "w") as f:
        f.write(MIGRATE_PY)
    sftp.close()
    print(run(c, f"{PY} {B}/_run_migrate.py"))
    print("verify:", run(c, f"{PY} -c \"from sqlalchemy import create_engine, inspect; import os; from dotenv import load_dotenv; load_dotenv('{B}/.env'); e=create_engine(os.getenv('DATABASE_URL')); t=inspect(e).get_table_names(); print('class_diary_entries' in t, 'almanac_events' in t)\""))
    c.exec_command("pm2 restart sunkidz-api")
    time.sleep(6)
    print("health:", run(c, "curl -s http://127.0.0.1:8001/health"))
    print("jwt:", run(c, f"grep JWT_ACCESS_TOKEN {B}/.env"))
    c.close()


if __name__ == "__main__":
    main()
