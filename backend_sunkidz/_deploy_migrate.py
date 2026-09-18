
import os
os.chdir('/root/sunkidz/sunkidz/backend')
os.environ['PYTHONPATH'] = '/root/sunkidz/sunkidz/backend'
from alembic.config import Config
from alembic import command
cfg = Config('alembic.ini')
cfg.set_main_option('script_location', 'alembic')
command.upgrade(cfg, 'heads')
print('OK')
