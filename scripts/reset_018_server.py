"""Drop tables created by create_all so alembic can own them, then upgrade."""
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


SCRIPT = f"""
import os
os.chdir({REMOTE_BACKEND!r})
os.environ['PYTHONPATH'] = {REMOTE_BACKEND!r}

from sqlalchemy import create_engine, text, inspect
from app.core.config import settings

engine = create_engine(settings.database_url)
with engine.begin() as conn:
    insp = inspect(conn)
    # 1) Inspect what columns / tables already exist.
    msg_cols = {{c['name'] for c in insp.get_columns('messages')}} if insp.has_table('messages') else set()
    has_daily = insp.has_table('daily_stories')
    print('messages_cols_pre:', sorted(msg_cols))
    print('daily_stories_exists:', has_daily)

    # 2) Add attachment columns to messages if missing (so 017 is logically applied).
    needed = {{
        'attachment_path': 'VARCHAR(500)',
        'attachment_name': 'VARCHAR(255)',
        'attachment_mime': 'VARCHAR(100)',
        'attachment_kind': 'VARCHAR(20)',
    }}
    for col, ddl in needed.items():
        if col not in msg_cols:
            conn.execute(text(f"ALTER TABLE messages ADD COLUMN {{col}} {{ddl}}"))
            print('added', col)

    # 3) Drop auto-created daily_story tables so alembic can recreate cleanly.
    if has_daily:
        conn.execute(text('DROP TABLE IF EXISTS daily_story_classes CASCADE'))
        conn.execute(text('DROP TABLE IF EXISTS daily_story_branches CASCADE'))
        conn.execute(text('DROP TABLE IF EXISTS daily_stories CASCADE'))
        print('dropped daily_* tables')

    # 4) Stamp alembic_version to 017 since msg attachment columns are in place.
    cur = conn.execute(text("SELECT version_num FROM alembic_version")).fetchone()
    print('alembic_version before:', cur[0] if cur else None)
    conn.execute(text("UPDATE alembic_version SET version_num = '017_chat_message_attachments' WHERE version_num = '016_class_diary_and_almanac'"))
    cur = conn.execute(text("SELECT version_num FROM alembic_version")).fetchone()
    print('alembic_version after:', cur[0] if cur else None)

print('--- running alembic upgrade 018 ---')
from alembic.config import Config
from alembic import command
cfg = Config('alembic.ini')
cfg.set_main_option('script_location', 'alembic')
command.upgrade(cfg, '018_daily_stories')
print('--- after ---')
command.current(cfg)
"""


def main():
    client = connect()
    sftp = client.open_sftp()
    with sftp.file(f"{REMOTE_BACKEND}/_reset018.py", "w") as f:
        f.write(SCRIPT)
    sftp.close()
    _, o, e = client.exec_command(f"{VENV_PY} {REMOTE_BACKEND}/_reset018.py 2>&1")
    print(o.read().decode())
    err = e.read().decode()
    if err:
        print("STDERR:", err)
    client.exec_command("pm2 restart sunkidz-api")
    import time
    time.sleep(5)
    _, o, _ = client.exec_command("curl -s http://127.0.0.1:8001/health; echo")
    print("HEALTH:", o.read().decode())
    _, o, _ = client.exec_command(
        "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8001/api/v1/stories; echo"
    )
    print("GET /api/v1/stories ->", o.read().decode().strip())
    client.close()


if __name__ == "__main__":
    main()
