import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Fetching from GitHub...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git fetch origin master")
    print("   Fetched")
    
    print("2. Hard reset to origin/master...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git reset --hard origin/master")
    output = stdout.read().decode()
    print(f"   {output[:100]}")
    
    print("3. Verifying file...")
    _, stdout, _ = client.exec_command(f"wc -l {backend_dir}/app/api/learning_modules.py")
    lines = stdout.read().decode().strip()
    print(f"   {lines}")
    
    print("4. Checking for endpoint...")
    _, stdout, _ = client.exec_command(f"grep 'for-student' {backend_dir}/app/api/learning_modules.py | head -1")
    endpoint = stdout.read().decode().strip()
    if endpoint:
        print(f"   ✓ Found: {endpoint[:60]}")
    
    print("\n5. Restarting backend...")
    client.exec_command("pkill -9 python")
    time.sleep(3)
    client.exec_command(f"cd {backend_dir} && nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &")
    time.sleep(5)
    
    print("6. Testing endpoint...")
    _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/for-student/test-123")
    resp = stdout.read().decode()
    
    if "Student not found" in resp:
        print("   ✓✓✓ WORKING! ✓✓✓")
    elif "404" in resp:
        print("   ✗ Still 404")
        print("   Testing backend process...")
        _, stdout, _ = client.exec_command("ps aux | grep 'uvicorn.*app.main'")
        proc = stdout.read().decode()
        print(f"   Process: {proc[:100] if proc else 'Not running'}")
    else:
        print(f"   Response: {resp[:100]}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
