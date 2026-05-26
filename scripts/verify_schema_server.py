"""Verify the new schema on server via SQLAlchemy (using app config)."""
import os
import sys
import paramiko

HOSTS = ["10.0.0.5", "93.127.195.245"]
USER = "root"
PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
REMOTE_BACKEND = "/root/sunkidz/sunkidz/backend"
VENV_PY = f"{REMOTE_BACKEND}/venv/bin/python"

SCRIPT = f"""
import os
os.chdir({REMOTE_BACKEND!r})
os.environ['PYTHONPATH'] = {REMOTE_BACKEND!r}
from sqlalchemy import create_engine, inspect
from app.core.config import settings

engine = create_engine(settings.database_url)
insp = inspect(engine)

for t in ('messages', 'daily_stories', 'daily_story_branches', 'daily_story_classes'):
    if insp.has_table(t):
        cols = [c['name'] for c in insp.get_columns(t)]
        print(f"{{t}}: {{cols}}")
    else:
        print(f"{{t}}: MISSING")
"""


def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    connected = False
    for host in HOSTS:
        try:
            client.connect(host, username=USER, password=PASSWORD, timeout=25)
            print(f"Connected to {host}")
            connected = True
            break
        except Exception as e:
            print(f"{host}: {e}")
    if not connected:
        sys.exit("Could not connect.")

    sftp = client.open_sftp()
    with sftp.file(f"{REMOTE_BACKEND}/_verify_schema.py", "w") as f:
        f.write(SCRIPT)
    sftp.close()
    _, o, e = client.exec_command(f"{VENV_PY} {REMOTE_BACKEND}/_verify_schema.py 2>&1")
    print(o.read().decode())
    err = e.read().decode()
    if err:
        print("STDERR:", err)
    client.close()


if __name__ == "__main__":
    main()
