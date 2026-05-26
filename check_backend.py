import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Checking for Python syntax errors...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python -m py_compile app/api/learning_modules.py 2>&1")
    error_output = stdout.read().decode()
    if error_output:
        print(f"   ✗ Syntax error:\n{error_output}")
    else:
        print("   ✓ No syntax errors")
    
    print("\n2. Checking if module imports...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python -c 'from app.api import learning_modules; print(\"OK\")' 2>&1")
    import_output = stdout.read().decode()
    print(f"   {import_output}")
    
    print("\n3. Checking backend logs for errors...")
    _, stdout, _ = client.exec_command("tail -50 /tmp/backend.log | grep -i 'error\\|exception\\|traceback' | tail -20")
    log_errors = stdout.read().decode()
    if log_errors:
        print(f"   Errors found:\n{log_errors}")
    else:
        print("   ✓ No errors in logs")
    
    print("\n4. Testing main app import...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python -c 'from app.main import app; print(app.routes[:3])' 2>&1")
    routes_output = stdout.read().decode()
    print(f"   Routes test: {routes_output[:200]}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
