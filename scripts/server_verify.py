import os
import paramiko

PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
B = "/root/sunkidz/sunkidz/backend"
PY = f"{B}/venv/bin/python"

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("10.0.0.5", username="root", password=PASSWORD, timeout=25)

def run(cmd):
    _, o, e = c.exec_command(cmd, timeout=60)
    return (o.read() + e.read()).decode("utf-8", "replace")

checks = [
    ("jwt", f"grep JWT {B}/.env"),
    ("diary", f"test -f {B}/app/api/diary.py && echo ok"),
    ("almanac", f"test -f {B}/app/api/almanac.py && echo ok"),
    ("tables", f"{PY} -c \"import os; from dotenv import load_dotenv; from sqlalchemy import create_engine, inspect; load_dotenv('{B}/.env'); e=create_engine(os.getenv('DATABASE_URL')); print(sorted([t for t in inspect(e).get_table_names() if 'diary' in t or 'almanac' in t]))\""),
    ("alembic_ver", f"{PY} -c \"import os; from dotenv import load_dotenv; from sqlalchemy import create_engine, text; load_dotenv('{B}/.env'); e=create_engine(os.getenv('DATABASE_URL')); print(e.connect().execute(text('select version_num from alembic_version')).scalar())\""),
    ("docs", "curl -s http://127.0.0.1:8001/openapi.json | grep -o '/api/v1/diary[^\"]*' | head -3"),
    ("health", "curl -s http://127.0.0.1:8001/health"),
]
for name, cmd in checks:
    print(f"--- {name} ---")
    print(run(cmd).strip())
c.close()
