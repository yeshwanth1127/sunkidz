
import os, sys
os.chdir(r'/root/sunkidz/sunkidz/backend')
sys.path.insert(0, r'/root/sunkidz/sunkidz/backend')
from sqlalchemy import inspect
from app.core.database import engine

insp = inspect(engine)
print('== class_diary_entries columns ==')
for c in insp.get_columns('class_diary_entries'):
    print(' -', c['name'], c['type'])
print('== almanac_events columns ==')
for c in insp.get_columns('almanac_events'):
    print(' -', c['name'], c['type'])
print('== diary indexes ==')
for idx in insp.get_indexes('class_diary_entries'):
    print(' -', idx)
