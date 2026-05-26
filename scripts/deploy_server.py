"""Deploy latest backend to Hostinger and run migrations. Run from LAN/VPN."""
import os
import paramiko
import sys
import time
from pathlib import Path

HOSTS = ["10.0.0.5", "93.127.195.245"]
USER = "root"
PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
REMOTE_BACKEND = "/root/sunkidz/sunkidz/backend"
VENV_PY = f"{REMOTE_BACKEND}/venv/bin/python"
VENV_ALEMBIC = f"{REMOTE_BACKEND}/venv/bin/alembic"
LOCAL_BACKEND = Path(__file__).resolve().parent.parent / "backend"

# Files/dirs to sync for diary/almanac/session work
UPLOAD_PATHS = [
    "app/api/diary.py",
    "app/api/almanac.py",
    "app/api/teacher.py",
    "app/main.py",
    "app/models/class_diary.py",
    "app/models/almanac_event.py",
    "app/models/syllabus_holiday.py",
    "app/models/__init__.py",
    "app/models/branch.py",
    "app/core/class_names.py",
    "app/schemas/diary.py",
    "app/schemas/almanac.py",
    "app/schemas/admin.py",
    "app/services/class_access.py",
    "alembic/versions/014_branch_system_type.py",
    "alembic/versions/015_rename_kreedo_to_sunkidz.py",
    "alembic/versions/016_class_diary_and_almanac.py",
    "alembic/versions/017_chat_message_attachments.py",
    "app/api/chat.py",
    "app/api/syllabus.py",
    "app/models/message.py",
    "app/services/media_files.py",
    "app/api/stories.py",
    "app/models/daily_story.py",
    "app/schemas/stories.py",
    "alembic/versions/018_daily_stories.py",
    "app/api/birthdays.py",
    "app/api/admin.py",
    "app/api/diary.py",
    "app/api/almanac.py",
    "app/models/class_diary.py",
    "app/models/almanac_event.py",
    "app/schemas/diary.py",
    "app/schemas/almanac.py",
    "alembic/versions/019_per_student_diary_global_events.py",
    "app/api/learning_modules.py",
    "app/models/learning_module.py",
    "alembic/versions/020_learning_modules.py",
    ".env.example",
]


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
    sys.exit("Could not connect. Use VPN/LAN.")


def main():
    client = connect()
    sftp = client.open_sftp()

    for rel in UPLOAD_PATHS:
        local = LOCAL_BACKEND / rel
        remote = f"{REMOTE_BACKEND}/{rel.replace(chr(92), '/')}"
        if not local.exists():
            print(f"SKIP (missing local): {rel}")
            continue
        remote_dir = "/".join(remote.split("/")[:-1])
        try:
            sftp.stat(remote_dir)
        except FileNotFoundError:
            parts = remote_dir.split("/")
            cur = ""
            for p in parts:
                if not p:
                    continue
                cur += "/" + p
                try:
                    sftp.stat(cur)
                except FileNotFoundError:
                    sftp.mkdir(cur)
        sftp.put(str(local), remote)
        print(f"UP {rel}")

    # JWT 30 days on server .env
    _, o, _ = client.exec_command(
        f"grep -q '^JWT_ACCESS_TOKEN_EXPIRE_MINUTES=43200' {REMOTE_BACKEND}/.env "
        f"|| sed -i 's/^JWT_ACCESS_TOKEN_EXPIRE_MINUTES=.*/JWT_ACCESS_TOKEN_EXPIRE_MINUTES=43200/' {REMOTE_BACKEND}/.env; "
        f"grep JWT_ACCESS_TOKEN {REMOTE_BACKEND}/.env"
    )
    print("ENV:", o.read().decode())

    migrate_script = f"""
import os
os.chdir({repr(REMOTE_BACKEND)})
os.environ['PYTHONPATH'] = {repr(REMOTE_BACKEND)}
from alembic.config import Config
from alembic import command
cfg = Config('alembic.ini')
cfg.set_main_option('script_location', 'alembic')
command.upgrade(cfg, 'heads')
print('OK')
"""
    sftp = client.open_sftp()
    with sftp.file(f"{REMOTE_BACKEND}/_deploy_migrate.py", "w") as f:
        f.write(migrate_script)
    sftp.close()
    _, o, e = client.exec_command(f"{VENV_PY} {REMOTE_BACKEND}/_deploy_migrate.py 2>&1")
    print("MIGRATE:\n", o.read().decode(), e.read().decode())

    _, o, _ = client.exec_command(
        f"cd {REMOTE_BACKEND} && {VENV_PY} -m scripts.seed_classes 2>&1 | tail -8"
    )
    print("SEED:", o.read().decode())

    client.exec_command("pm2 restart sunkidz-api")
    time.sleep(6)
    _, o, _ = client.exec_command("curl -s http://127.0.0.1:8001/health; echo")
    print("HEALTH:", o.read().decode())

    sftp.close()
    client.close()
    print("Deploy done.")


if __name__ == "__main__":
    main()
