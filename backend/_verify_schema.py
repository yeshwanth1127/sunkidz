
import os
os.chdir('/root/sunkidz/sunkidz/backend')
os.environ['PYTHONPATH'] = '/root/sunkidz/sunkidz/backend'
from sqlalchemy import create_engine, inspect
from app.core.config import settings

engine = create_engine(settings.database_url)
insp = inspect(engine)

for t in ('messages', 'daily_stories', 'daily_story_branches', 'daily_story_classes'):
    if insp.has_table(t):
        cols = [c['name'] for c in insp.get_columns(t)]
        print(f"{t}: {cols}")
    else:
        print(f"{t}: MISSING")
