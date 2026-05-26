"""Audit Hostinger backend at 10.0.0.5 — run: python scripts/server_audit.py"""
import os
import paramiko
import sys

HOSTS = ["10.0.0.5", "93.127.195.245"]
USER = "root"
PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
BACKEND = "/root/sunkidz/sunkidz/backend"


def run(client, cmd: str) -> str:
    _, stdout, stderr = client.exec_command(cmd, timeout=60)
    out = stdout.read().decode("utf-8", errors="replace")
    err = stderr.read().decode("utf-8", errors="replace")
    return (out + err).strip()


def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    connected_host = None
    last_err = None
    for host in HOSTS:
        try:
            client.connect(host, username=USER, password=PASSWORD, timeout=25)
            connected_host = host
            break
        except Exception as e:
            last_err = e
    if not connected_host:
        print(f"CONNECT_FAILED: {last_err}")
        print("Tried:", ", ".join(HOSTS))
        print("Connect to VPN/LAN, then run: python scripts/server_audit.py")
        sys.exit(1)
    print(f"Connected to {connected_host}\n")

    checks = [
        ("hostname", "hostname"),
        ("pm2", "pm2 show sunkidz-api 2>&1 | grep -E 'status|restarts|uptime' || true"),
        ("jwt_env", f"grep JWT_ACCESS_TOKEN_EXPIRE_MINUTES {BACKEND}/.env 2>/dev/null || echo MISSING"),
        ("alembic_head", f"cd {BACKEND} && alembic current 2>&1 | tail -5"),
        ("diary_api", f"test -f {BACKEND}/app/api/diary.py && echo YES || echo NO"),
        ("almanac_api", f"test -f {BACKEND}/app/api/almanac.py && echo YES || echo NO"),
        ("main_routers", f"grep -E 'diary_api|almanac_api' {BACKEND}/app/main.py || echo NOT_IN_MAIN"),
        ("class_names", f"grep SUNKIDZ {BACKEND}/app/core/class_names.py 2>/dev/null | head -1 || echo OLD_KREEDO"),
        ("tables", f"cd {BACKEND} && python -c \""
                   "from sqlalchemy import create_engine, inspect; "
                   "import os; "
                   "from dotenv import load_dotenv; "
                   "load_dotenv('.env'); "
                   "e=create_engine(os.getenv('DATABASE_URL','')); "
                   "t=inspect(e).get_table_names(); "
                   "print('class_diary_entries' in t, 'almanac_events' in t)\" 2>&1"),
        ("health", "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8000/health 2>/dev/null || echo curl_failed"),
        ("recent_errors", f"tail -15 {BACKEND}/logs/pm2-error.log 2>/dev/null || tail -15 /root/.pm2/logs/sunkidz-api-error.log 2>/dev/null || echo no_log"),
    ]

    for name, cmd in checks:
        print(f"\n=== {name} ===")
        print(run(client, cmd))

    client.close()
    print("\n=== audit done ===")


if __name__ == "__main__":
    main()
