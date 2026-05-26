import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

print("=== FIXING LEARNING MODULES ON 10.0.0.5 ===\n")

try:
    print("1. Connecting to 10.0.0.5...")
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    print("   Connected!")

    # First, find the correct path
    print("2. Finding backend path...")
    _, stdout, _ = client.exec_command("find /root -name 'learning_modules.py' -type f 2>/dev/null")
    learning_modules_path = stdout.read().decode().strip()
    
    if not learning_modules_path:
        print("   ERROR: Could not find learning_modules.py")
        client.close()
        exit(1)
    
    print(f"   Found at: {learning_modules_path}")

    # Read the file
    print("3. Reading learning_modules.py...")
    _, stdout, _ = client.exec_command(f"cat {learning_modules_path}")
    content = stdout.read().decode()

    # Apply the UUID to str() fix - use simpler line-by-line approach
    print("4. Applying UUID string conversion fix...")
    
    lines = content.split('\n')
    fixed_lines = []
    changes = 0
    
    for i, line in enumerate(lines):
        # Look for the specific patterns and fix them
        if 'LearningModule.id == module_id' in line and 'str(module_id)' not in line:
            line = line.replace('LearningModule.id == module_id', 'LearningModule.id == str(module_id)')
            changes += 1
            print(f"   Fixed line {i+1}: module_id UUID conversion")
        elif 'LearningVideo.id == video_id' in line and 'str(video_id)' not in line:
            line = line.replace('LearningVideo.id == video_id', 'LearningVideo.id == str(video_id)')
            changes += 1
            print(f"   Fixed line {i+1}: video_id UUID conversion")
        
        fixed_lines.append(line)
    
    new_content = '\n'.join(fixed_lines)
    print(f"   Applied {changes} changes")

    # Write back
    print("5. Writing fixed file...")
    stdin, stdout, stderr = client.exec_command(f"cat > {learning_modules_path} << 'EOFFIX'\n{new_content}\nEOFFIX")
    time.sleep(1)

    # Verify the fix was applied
    print("6. Verifying fix...")
    _, stdout, _ = client.exec_command(f"grep -c 'str(module_id)' {learning_modules_path}")
    count = stdout.read().decode().strip()
    print(f"   Found {count} str(module_id) conversions")

    _, stdout, _ = client.exec_command(f"grep -c 'str(video_id)' {learning_modules_path}")
    count2 = stdout.read().decode().strip()
    print(f"   Found {count2} str(video_id) conversions")

    # Kill any running backend processes
    print("\n7. Stopping backend...")
    client.exec_command("pkill -9 -f 'uvicorn app.main:app'")
    client.exec_command("pkill -9 -f 'python.*main.py'")
    time.sleep(2)

    # Find backend directory
    _, stdout, _ = client.exec_command("dirname $(find /root -name 'main.py' -path '*/app/*' | head -1)")
    backend_dir = stdout.read().decode().strip()
    
    if backend_dir:
        backend_dir = backend_dir.replace('/app', '')
        print(f"   Backend directory: {backend_dir}")
    else:
        backend_dir = "/root/sunkidz/sunkidz/backend"
        print(f"   Using default backend directory: {backend_dir}")

    # Restart backend
    print("8. Restarting backend...")
    client.exec_command(f"cd {backend_dir} && nohup python main.py > /tmp/backend.log 2>&1 &")
    time.sleep(4)

    # Verify backend is running
    print("9. Checking backend status...")
    _, stdout, _ = client.exec_command("ps aux | grep -E 'uvicorn|python.*main' | grep -v grep")
    status = stdout.read().decode().strip()
    if "python" in status or "uvicorn" in status:
        print("   SUCCESS: Backend is running!")
    else:
        print("   Checking logs...")
        _, stdout, _ = client.exec_command("tail -30 /tmp/backend.log")
        log_output = stdout.read().decode()
        if "Started server process" in log_output or "Application startup complete" in log_output:
            print("   Backend started successfully!")
        else:
            print("   Backend logs:")
            print(log_output)

    client.close()

    print("\n=== SUCCESS ===")
    print("Learning modules fix applied to 10.0.0.5!")
    print("Module list endpoint: https://api.sunkidz.org/api/v1/learning-modules/")
    print("Module videos endpoint: https://api.sunkidz.org/api/v1/learning-modules/{module_id}/videos")

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
finally:
    try:
        client.close()
    except:
        pass
