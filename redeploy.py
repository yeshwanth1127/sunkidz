import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

print("=== PULLING NEW CODE ===\n")

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Pulling latest from GitHub...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git pull origin master 2>&1")
    pull_output = stdout.read().decode()
    print(pull_output[:300])
    
    print("\n2. Verifying file update...")
    _, stdout, _ = client.exec_command(f"grep -c 'for-student' {backend_dir}/app/api/learning_modules.py")
    count = stdout.read().decode().strip()
    print(f"   'for-student' in file: {count} times")
    
    print("\n3. Killing old backend...")
    client.exec_command("pkill -9 python")
    time.sleep(2)
    
    print("4. Starting new backend...")
    client.exec_command(f"cd {backend_dir} && nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &")
    time.sleep(5)
    
    print("5. Testing endpoints...")
    
    # Test for-student endpoint with invalid student (should get 404 Student not found)
    _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/for-student/test-id")
    resp = stdout.read().decode()
    
    if "Student not found" in resp:
        print("   ✓ GET /learning-modules/for-student/{id}: WORKING!")
    elif "404" in resp:
        print("   ✗ Endpoint still 404")
    else:
        print(f"   Response: {resp[:100]}")
    
    # Test process
    _, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
    if stdout.read().decode():
        print("   ✓ Backend running")
    
    client.close()
    print("\n=== READY FOR TESTING ===")

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
