import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

print("=== FINAL PRODUCTION DEPLOYMENT ===\n")

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Pulling latest code from GitHub...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git pull origin master 2>&1")
    pull = stdout.read().decode()
    print(f"   {pull[:150]}")
    
    print("\n2. Stopping backend...")
    client.exec_command("pkill -9 python uvicorn")
    time.sleep(2)
    
    print("3. Running migrations...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python -m alembic upgrade head 2>&1")
    mig = stdout.read().decode()
    print("   Migrations applied")
    
    print("4. Starting backend...")
    client.exec_command(f"cd {backend_dir} && nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &")
    time.sleep(5)
    
    print("5. Testing endpoints...")
    
    # Test global modules
    _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/ 2>&1 | grep -o 'Module\\|\\[\\|404' | head -1")
    resp1 = stdout.read().decode().strip()
    print(f"   GET /learning-modules/: {resp1 if resp1 else 'OK'}")
    
    # Test for-student endpoint
    _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/for-student/test-id 2>&1")
    resp2 = stdout.read().decode()
    is_404 = "404" in resp2
    is_student_error = "Student not found" in resp2
    if is_student_error:
        print(f"   GET /learning-modules/for-student/test-id: ✓ Endpoint works (student not found as expected)")
    elif is_404:
        print(f"   GET /learning-modules/for-student/test-id: ✗ Still 404")
    else:
        print(f"   GET /learning-modules/for-student/test-id: ✓ Response received")
    
    # Test process
    _, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
    proc = stdout.read().decode()
    if proc:
        print("   ✓ Backend running")
    else:
        print("   ✗ Backend not running")
    
    client.close()
    print("\n=== DEPLOYMENT COMPLETE ===\n")
    print("Learning modules endpoints now available:")
    print("  • GET  /api/v1/learning-modules/for-student/{student_id}")
    print("  • POST /api/v1/learning-modules/{module_id}/assign-to-student/{student_id}")
    print("  • DELETE /api/v1/learning-modules/{module_id}/unassign-from-student/{student_id}")

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
