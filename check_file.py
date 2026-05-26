import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Checking if learning_modules.py exists...")
    _, stdout, _ = client.exec_command(f"ls -la {backend_dir}/app/api/learning_modules.py")
    ls_output = stdout.read().decode()
    print(f"   {ls_output}")
    
    print("\n2. Checking if it has the new endpoint...")
    _, stdout, _ = client.exec_command(f"grep -n 'for-student' {backend_dir}/app/api/learning_modules.py | head -2")
    grep_output = stdout.read().decode()
    print(f"   {grep_output}")
    
    print("\n3. Checking if router is imported in main.py...")
    _, stdout, _ = client.exec_command(f"grep -n 'learning_modules' {backend_dir}/app/main.py | head -3")
    import_output = stdout.read().decode()
    print(f"   {import_output}")
    
    print("\n4. Checking Python syntax...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python3 -m py_compile app/api/learning_modules.py 2>&1 || echo 'Syntax check done'")
    syntax_output = stdout.read().decode()
    print(f"   {syntax_output[:200]}")
    
    print("\n5. Checking if route is registered at all...")
    _, stdout, _ = client.exec_command(f"curl -s http://localhost:8000/docs | grep -i 'learning\\|module' | head -5")
    docs_check = stdout.read().decode()
    print(f"   {docs_check[:200]}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
