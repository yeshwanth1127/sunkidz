import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    print("1. Stopping backend...")
    client.exec_command("pkill -9 -f 'python.*main.py'")
    time.sleep(2)
    
    print("2. Finding backend directory...")
    _, stdout, _ = client.exec_command("find /root -name 'main.py' -path '*/app/*' | head -1")
    main_path = stdout.read().decode().strip()
    backend_dir = main_path.replace('/app/main.py', '') if main_path else '/root/sunkidz/sunkidz/backend'
    print(f"   Backend: {backend_dir}")
    
    print("3. Starting backend...")
    client.exec_command(f"cd {backend_dir} && nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &")
    time.sleep(4)
    
    print("4. Checking status...")
    _, stdout, _ = client.exec_command("ps aux | grep 'python.*main\\|uvicorn' | grep -v grep | head -1")
    result = stdout.read().decode()
    if "python" in result:
        print("   ✓ Backend restarted successfully")
    else:
        print("   ⚠ Checking logs...")
        _, stdout, _ = client.exec_command("tail -20 /tmp/backend.log")
        logs = stdout.read().decode()
        print(f"   Logs:\n{logs}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
