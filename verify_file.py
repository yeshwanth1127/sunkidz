import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Checking file size...")
    _, stdout, _ = client.exec_command(f"wc -l {backend_dir}/app/api/learning_modules.py")
    size = stdout.read().decode().strip()
    print(f"   {size}")
    
    print("\n2. Checking for new endpoint...")
    _, stdout, _ = client.exec_command(f"grep -c 'for-student' {backend_dir}/app/api/learning_modules.py")
    count = stdout.read().decode().strip()
    print(f"   'for-student' appears {count} times")
    
    print("\n3. Checking last modified time...")
    _, stdout, _ = client.exec_command(f"stat {backend_dir}/app/api/learning_modules.py | grep Modify")
    mtime = stdout.read().decode().strip()
    print(f"   {mtime}")
    
    print("\n4. Reading the actual routes...")
    _, stdout, _ = client.exec_command(f"grep -n '@router' {backend_dir}/app/api/learning_modules.py")
    routes = stdout.read().decode()
    print(f"   Routes in file:\n{routes}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
