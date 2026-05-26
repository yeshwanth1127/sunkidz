import paramiko
import time
import sys

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

print("=== RESTARTING BACKEND WITH NEW CODE ===\n")

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Killing all Python processes...")
    client.exec_command("pkill -9 python")
    time.sleep(1)
    
    print("2. Pulling latest code...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git pull origin master 2>&1")
    pull_output = stdout.read().decode()
    print(f"   Git pull: {pull_output[:100]}...")
    
    print("3. Running migrations...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python -m alembic upgrade head 2>&1")
    mig_output = stdout.read().decode()
    if "error" in mig_output.lower():
        print(f"   ⚠ Migration output: {mig_output[:200]}")
    else:
        print("   ✓ Migrations applied")
    
    print("4. Starting uvicorn server...")
    start_cmd = f"cd {backend_dir} && nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload > /tmp/backend.log 2>&1 &"
    client.exec_command(start_cmd)
    time.sleep(5)
    
    print("5. Verifying process...")
    _, stdout, _ = client.exec_command("ps aux | grep -E 'uvicorn|python.*main' | grep -v grep")
    proc_output = stdout.read().decode()
    if proc_output:
        print("   ✓ Backend is running")
        print(f"   Process: {proc_output[:80]}...")
    else:
        print("   ⚠ No process found, checking logs...")
        _, stdout, _ = client.exec_command("tail -30 /tmp/backend.log")
        logs = stdout.read().decode()
        print(f"   Logs:\n{logs}")
    
    print("\n6. Testing endpoints...")
    time.sleep(2)
    _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/ -w '\\nHTTP_%{http_code}' 2>&1 | tail -5")
    test_output = stdout.read().decode()
    print(f"   GET /learning-modules/: {test_output}")
    
    client.close()
    print("\n=== RESTART COMPLETE ===")

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
finally:
    try:
        client.close()
    except:
        pass
