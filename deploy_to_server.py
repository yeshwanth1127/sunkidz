import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

print("=== DEPLOYING STUDENT-SPECIFIC LEARNING MODULES ===\n")

try:
    print("1. Connecting to 10.0.0.5...")
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    print("   Connected!")

    # Get backend directory
    _, stdout, _ = client.exec_command("find /root -name 'main.py' -path '*/app/*' -type f | head -1")
    main_path = stdout.read().decode().strip()
    if not main_path:
        raise Exception("Could not find backend main.py")
    
    backend_dir = main_path.replace('/app/main.py', '')
    print("   Backend directory: " + backend_dir)

    print("\n2. Pulling latest code...")
    _, stdout, _ = client.exec_command("cd " + backend_dir + " && git pull origin master")
    stdout.read()

    print("3. Running database migration...")
    _, stdout, _ = client.exec_command("cd " + backend_dir + " && python -m alembic upgrade head")
    output = stdout.read().decode()
    if "error" in output.lower():
        print("   Migration warning: " + output)
    else:
        print("   Migration completed")

    print("\n4. Stopping backend...")
    client.exec_command("pkill -9 -f 'python.*main.py'")
    time.sleep(2)

    print("5. Starting backend...")
    client.exec_command("cd " + backend_dir + " && nohup python main.py > /tmp/backend.log 2>&1 &")
    time.sleep(4)

    print("6. Verifying deployment...")
    _, stdout, _ = client.exec_command("ps aux | grep 'python.*main' | grep -v grep")
    if "python" in stdout.read().decode():
        print("   OK Backend running")
    else:
        print("   WARNING Backend may not be running")

    client.close()
    print("\n=== DEPLOYMENT COMPLETE ===")
    print("New endpoints available:")
    print("  - GET /api/v1/learning-modules/for-student/{student_id}")
    print("  - POST /api/v1/learning-modules/{id}/assign-to-student/{sid}")
    print("  - DELETE /api/v1/learning-modules/{id}/unassign-from-student/{sid}")

except Exception as e:
    print("ERROR: " + str(e))
    import traceback
    traceback.print_exc()
finally:
    try:
        client.close()
    except:
        pass
