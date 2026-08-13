
import os
os.chdir('/root/sunkidz/sunkidz/backend')
os.environ['PYTHONPATH'] = '/root/sunkidz/sunkidz/backend'

from sqlalchemy import create_engine, text, inspect
from app.core.config import settings

engine = create_engine(settings.database_url)
with engine.begin() as conn:
    insp = inspect(conn)
    # 1) Inspect what columns / tables already exist.
    msg_cols = {c['name'] for c in insp.get_columns('messages')} if insp.has_table('messages') else set()
    has_daily = insp.has_table('daily_stories')
    print('messages_cols_pre:', sorted(msg_cols))
    print('daily_stories_exists:', has_daily)

    # 2) Add attachment columns to messages if missing (so 017 is logically applied).
    needed = {
        'attachment_path': 'VARCHAR(500)',
        'attachment_name': 'VARCHAR(255)',
        'attachment_mime': 'VARCHAR(100)',
        'attachment_kind': 'VARCHAR(20)',
    }
    for col, ddl in needed.items():
        if col not in msg_cols:
            conn.execute(text(f"ALTER TABLE messages ADD COLUMN {col} {ddl}"))
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
