
import os
os.chdir('/root/sunkidz/sunkidz/backend')
os.environ['PYTHONPATH'] = '/root/sunkidz/sunkidz/backend'
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
