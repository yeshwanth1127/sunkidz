
import os
os.chdir('/root/sunkidz/sunkidz/backend')
os.environ['PYTHONPATH'] = '/root/sunkidz/sunkidz/backend'
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
