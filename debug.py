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
    
    print("1. Checking backend log...")
    _, stdout, _ = client.exec_command("tail -50 /tmp/backend.log")
    log = stdout.read().decode()
    print(log)
    
    print("\n2. Checking if Student model is imported...")
    _, stdout, _ = client.exec_command(f"grep 'from.*Student' {backend_dir}/app/api/learning_modules.py | head -3")
    imports = stdout.read().decode()
    print(f"   {imports if imports else 'Not found'}")
    
    print("\n3. Testing Python syntax...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python -c 'from app.api import learning_modules; print(dir(learning_modules.router))' 2>&1")
    result = stdout.read().decode()
    print(f"   {result[:150]}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
