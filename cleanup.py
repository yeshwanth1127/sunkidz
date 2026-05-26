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
    
    print("1. Cleaning untracked files...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git clean -fd alembic/versions/")
    print("   Cleaned")
    
    print("2. Pulling again...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git pull origin master 2>&1")
    pull = stdout.read().decode()
    if "Already up to date" in pull or "Fast-forward" in pull:
        print("   ✓ Pull successful")
    else:
        print(f"   {pull[:100]}")
    
    print("3. Verifying file...")
    _, stdout, _ = client.exec_command(f"grep -c 'for-student' {backend_dir}/app/api/learning_modules.py")
    count = stdout.read().decode().strip()
    print(f"   'for-student' appears: {count} times")
    
    if int(count) > 0:
        print("\n   ✓ FILE UPDATED!")
        
        print("\n4. Restarting backend...")
        client.exec_command("pkill -9 python")
        time.sleep(3)
        client.exec_command(f"cd {backend_dir} && nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &")
        time.sleep(5)
        
        print("5. Testing endpoint...")
        _, stdout, _ = client.exec_command("curl -s http://localhost:8000/api/v1/learning-modules/for-student/test-123")
        resp = stdout.read().decode()
        
        if "Student not found" in resp:
            print("   ✓✓✓ ENDPOINT WORKING! ✓✓✓")
        else:
            print(f"   Response: {resp[:150]}")
    else:
        print("   File still not updated")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
