import paramiko

HOST = "93.127.195.245"
USER = "root"
PASSWORD = "Exora@yeshwanth123"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("=== CHECKING PRODUCTION BACKEND (93.127.195.245) ===\n")

# Check the actual coordinator function
print("1. COORDINATOR BRANCH ID FUNCTION:")
_, stdout, _ = client.exec_command("cat /root/sunkidz/backend/app/api/coordinator.py | grep -A 7 'def _coordinator_branch_id'")
code = stdout.read().decode().strip()
print(code)
print()

# Check if backend is running
print("2. BACKEND STATUS:")
_, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
status = stdout.read().decode().strip()
print("RUNNING" if status else "NOT RUNNING")
print(status[:200] if status else "")
print()

# Check which port
if "port" in status:
    import re
    port = re.search(r'port (\d+)', status)
    if port:
        print(f"Backend running on port: {port.group(1)}")

client.close()
