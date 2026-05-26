"""Smoke test against the deployed server with a real admin login."""
import os
import sys
import paramiko

HOSTS = ["10.0.0.5", "93.127.195.245"]
USER = "root"
PASSWORD = os.environ.get("SUNKIDZ_SSH_PASSWORD", "?0Ng,&0O/xJ3i,vlo'zB")
BASE = "http://127.0.0.1:8001/api/v1"


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


def sh(client, cmd, label):
    _, o, e = client.exec_command(cmd)
    out = o.read().decode().strip()
    err = e.read().decode().strip()
    print(f"== {label} ==")
    if out:
        print(out)
    if err:
        print("STDERR:", err)
    print()


def main():
    client = connect()

    # Inspect new tables and columns
    sh(client, "sudo -u postgres psql -d sunkidz_lms -c \"\\d daily_stories\" 2>&1 | head -25", "daily_stories schema")
    sh(client, "sudo -u postgres psql -d sunkidz_lms -c \"\\d daily_story_branches\" 2>&1 | head -15", "daily_story_branches schema")
    sh(client, "sudo -u postgres psql -d sunkidz_lms -c \"\\d daily_story_classes\" 2>&1 | head -15", "daily_story_classes schema")
    sh(client, "sudo -u postgres psql -d sunkidz_lms -c \"\\d messages\" 2>&1", "messages schema")

    # API health + route presence (no auth)
    sh(client, f"curl -s {BASE.replace('/api/v1','')}/health; echo", "health")
    sh(client, f"curl -s -o /dev/null -w '%{{http_code}}' {BASE}/stories; echo", "GET /stories (no auth)")
    sh(client, f"curl -s -o /dev/null -w '%{{http_code}}' -X POST {BASE}/stories/upload; echo", "POST /stories/upload (no auth)")
    sh(client, f"curl -s -o /dev/null -w '%{{http_code}}' -X POST {BASE}/chat/threads/00000000-0000-0000-0000-000000000000/messages/upload; echo", "POST /chat/.../messages/upload (no auth)")

    # Try to login as default admin (if it exists) and call /stories with token
    LOGIN = (
        f"curl -s -X POST {BASE}/auth/login "
        "-H 'Content-Type: application/json' "
        "-d '{\"phone\":\"9999999999\",\"password\":\"admin123\"}'"
    )
    sh(client, LOGIN, "admin login attempt")

    client.close()


if __name__ == "__main__":
    main()
