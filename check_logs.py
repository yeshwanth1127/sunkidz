import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("=== CHECKING BACKEND APP.LOG ===")
_, stdout, _ = client.exec_command("tail -50 /root/sunkidz/sunkidz/backend/app.log 2>/dev/null || echo 'No log file'")
logs = stdout.read().decode().strip()
print(logs)

print("\n=== CHECKING IF DATABASE IS ACCESSIBLE FROM BACKEND ===")
cmd = "cd /root/sunkidz/sunkidz/backend && python -c \"from app.core.database import engine; print('DB accessible' if engine else 'DB not accessible')\" 2>&1"
_, stdout, _ = client.exec_command(cmd)
output = stdout.read().decode().strip()
print(output)

client.close()
