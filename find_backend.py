import paramiko
import time

SERVERS = [
    ("31.97.63.193", "Production API"),
    ("93.127.195.245", "Backup server"),
    ("10.0.0.5", "Internal staging"),
    ("10.0.0.1", "PostgreSQL")
]

USER = "root"
PASSWORD = "Exora@yeshwanth123"

print("Checking all servers...\n")

for host, label in SERVERS:
    print(f"=== {label} ({host}) ===")
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(host, username=USER, password=PASSWORD, timeout=5)

        # Check what's running
        _, stdout, _ = client.exec_command("ps aux | grep -E 'uvicorn|postgres|mysql' | grep -v grep | head -3")
        processes = stdout.read().decode().strip()

        if "uvicorn" in processes:
            print("BACKEND RUNNING:")
            print(processes[:200])
        elif "postgres" in processes:
            print("POSTGRESQL RUNNING")
        else:
            print("No backend/DB running")

        # Check coordinator.py fix
        _, stdout, _ = client.exec_command("cat /root/sunkidz/backend/app/api/coordinator.py 2>/dev/null | grep -c 'class_id.is_(None)'")
        has_old_code = stdout.read().decode().strip() == "1"
        print(f"Has OLD code (needs fix): {has_old_code}")

        client.close()
        print("Connection: OK\n")

    except Exception as e:
        print(f"Connection FAILED: {str(e)[:80]}\n")
