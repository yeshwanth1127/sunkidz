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
    
    print("1. Killing old processes...")
    client.exec_command("pkill -9 -f 'uvicorn.*app.main'")
    time.sleep(2)
    
    print("2. Starting backend with python3...")
    client.exec_command(f"cd {backend_dir} && nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &")
    time.sleep(5)
    
    print("3. Checking log...")
    _, stdout, _ = client.exec_command("tail -20 /tmp/backend.log 2>&1")
    log = stdout.read().decode()
    print(log)
    
    print("\n4. Testing endpoint...")
    _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/for-student/test-id")
    resp = stdout.read().decode()
    
    if "Student not found" in resp:
        print("   ✓✓✓ ENDPOINT WORKS! ✓✓✓")
    else:
        print(f"   Response: {resp[:200]}")
    
    print("\n5. Testing original endpoint too...")
    _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/ | head -c 50")
    resp2 = stdout.read().decode()
    if "[" in resp2 or "{" in resp2:
        print("   ✓ Original endpoint also working")
    else:
        print(f"   Response: {resp2[:100]}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
