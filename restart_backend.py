import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("Killing old backend process...")
_, stdout, _ = client.exec_command("pkill -f 'uvicorn app.main:app'")
time.sleep(2)

print("Starting new backend...")
_, stdout, _ = client.exec_command("cd /root/sunkidz/sunkidz/backend && python -m uvicorn app.main:app --host 0.0.0.0 --port 8001 &")
time.sleep(3)

print("Checking backend status...")
_, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
status = stdout.read().decode().strip()
if "uvicorn" in status:
    print("BACKEND RESTARTED SUCCESSFULLY")
    print(status)
else:
    print("ERROR: Backend did not start")

client.close()
