import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Checking for .env in backend...")
    _, stdout, _ = client.exec_command(f"cat {backend_dir}/.env 2>/dev/null || echo 'No .env file'")
    env = stdout.read().decode()
    print(f"   {env}")
    
    print("2. Checking current backend path structure...")
    _, stdout, _ = client.exec_command(f"ls -la {backend_dir}/*.py | head -5")
    ls = stdout.read().decode()
    print(f"   {ls}")
    
    print("3. Checking if there's a main app.py in root of backend...")
    _, stdout, _ = client.exec_command(f"find {backend_dir} -maxdepth 1 -name '*.py' -exec basename {{}} \\;")
    py_files = stdout.read().decode()
    print(f"   Python files in root: {py_files}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
