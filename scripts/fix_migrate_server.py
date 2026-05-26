"""Resolve multiple-heads and apply 017 + 018 on the server."""
import os
import sys
import paramiko

HOSTS = ["10.0.0.5", "93.127.195.245"]
USER = "root"
PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
REMOTE_BACKEND = "/root/sunkidz/sunkidz/backend"
VENV_PY = f"{REMOTE_BACKEND}/venv/bin/python"


def connect():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    for host in HOSTS:
        try:
            client.connect(host, username=USER, password=PASSWORD, timeout=25)
            print(f"Connected to {host}")
            return client
        except Exception as e:
            print(f"{host}: {e}")
    sys.exit("Could not connect.")


def run(client, cmd, label):
    _, o, e = client.exec_command(cmd)
    out = o.read().decode().strip()
    err = e.read().decode().strip()
    print(f"-- {label} --")
    if out:
        print(out)
    if err:
        print("STDERR:", err)


def main():
    client = connect()

    migrate_script = f"""
import os
os.chdir({repr(REMOTE_BACKEND)})
os.environ['PYTHONPATH'] = {repr(REMOTE_BACKEND)}
from alembic.config import Config
from alembic import command
from alembic.script import ScriptDirectory
cfg = Config('alembic.ini')
cfg.set_main_option('script_location', 'alembic')
script = ScriptDirectory.from_config(cfg)
print('HEADS:', script.get_heads())
print('CURRENT:')
command.current(cfg)
print('UPGRADING -> 018_daily_stories')
command.upgrade(cfg, '018_daily_stories')
print('AFTER:')
command.current(cfg)
"""
    sftp = client.open_sftp()
    with sftp.file(f"{REMOTE_BACKEND}/_fix_migrate.py", "w") as f:
        f.write(migrate_script)
    sftp.close()
    run(client, f"{VENV_PY} {REMOTE_BACKEND}/_fix_migrate.py 2>&1", "MIGRATE")

    client.exec_command("pm2 restart sunkidz-api")
    import time
    time.sleep(5)
    _, o, _ = client.exec_command("curl -s http://127.0.0.1:8001/health; echo")
    print("HEALTH:", o.read().decode())

    # Smoke test new endpoints exist (will 401 without auth — still proves route registered).
    _, o, _ = client.exec_command(
        "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8001/api/v1/stories; echo"
    )
    print("GET /api/v1/stories ->", o.read().decode().strip())

    client.close()


if __name__ == "__main__":
    main()
