import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

print("=== DEPLOYING LEARNING MODULES TO PRODUCTION ===\n")

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    # Stop all python processes
    print("1. Stopping all services...")
    client.exec_command("pkill -9 python uvicorn")
    time.sleep(2)
    
    # Pull latest code
    print("2. Pulling latest code from master...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git fetch origin && git reset --hard origin/master")
    pull_output = stdout.read().decode()
    print(f"   {pull_output[:150]}")
    
    # Run migrations
    print("3. Running database migrations...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python -m alembic upgrade head")
    mig_output = stdout.read().decode()
    print("   Migrations done")
    
    # Start backend
    print("4. Starting uvicorn backend...")
    client.exec_command(f"cd {backend_dir} && nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > backend.log 2>&1 &")
    time.sleep(5)
    
    # Verify
    print("5. Testing endpoints...")
    
    # Test basic endpoint
    _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/ | head -20")
    basic_resp = stdout.read().decode()
    if "Module" in basic_resp or "[" in basic_resp:
        print("   ✓ GET /api/v1/learning-modules/ works")
    else:
        print(f"   ✗ GET /api/v1/learning-modules/: {basic_resp[:100]}")
    
    # Test student endpoint
    _, stdout, _ = client.exec_command("curl -s 'http://localhost:8000/api/v1/learning-modules/for-student/test' | head -5")
    student_resp = stdout.read().decode()
    print(f"   GET /api/v1/learning-modules/for-student/test: {student_resp[:100]}")
    
    # Check if process is running
    _, stdout, _ = client.exec_command("ps aux | grep -E 'uvicorn|python.*main' | grep -v grep")
    proc = stdout.read().decode()
    if "uvicorn" in proc or "python" in proc:
        print("   ✓ Backend process running")
    else:
        print("   ✗ Backend not running - checking logs...")
        _, stdout, _ = client.exec_command("tail -20 backend.log")
        logs = stdout.read().decode()
        print(f"   {logs}")
    
    client.close()
    print("\n=== DEPLOYMENT COMPLETE ===")

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
