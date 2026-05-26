import paramiko

HOST = "31.97.63.193"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

print("Connecting to production backend at 31.97.63.193...")
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    print("Connected!")
except Exception as e:
    print(f"Could not connect with that password, trying root@93.127.195.245...")
    try:
        client.connect("93.127.195.245", username=USER, password=PASSWORD, timeout=10)
        print("Connected to 93.127.195.245!")
        HOST = "93.127.195.245"
    except:
        print("Could not connect to either server")
        exit(1)

# Check if the fix is needed
print("\nChecking if fix is needed...")
_, stdout, _ = client.exec_command("cat /root/sunkidz/backend/app/api/coordinator.py | grep -A 3 '_coordinator_branch_id' | head -6")
code = stdout.read().decode().strip()
print(code)

if "class_id.is_(None)" in code:
    print("\nFix needed! Applying fix...")

    # Read the file
    _, stdout, _ = client.exec_command("cat /root/sunkidz/backend/app/api/coordinator.py")
    file_content = stdout.read().decode()

    # Replace the line
    new_content = file_content.replace(
        """def _coordinator_branch_id(user: User, db: Session) -> UUID | None:
    a = db.query(BranchAssignment).filter(
        BranchAssignment.user_id == user.id,
        BranchAssignment.class_id.is_(None),
    ).first()
    return a.branch_id if a else None""",
        """def _coordinator_branch_id(user: User, db: Session) -> UUID | None:
    a = db.query(BranchAssignment).filter(
        BranchAssignment.user_id == user.id,
    ).first()
    return a.branch_id if a else None"""
    )

    # Write back
    _, stdout, _ = client.exec_command(f"cat > /root/sunkidz/backend/app/api/coordinator.py << 'EOF'\n{new_content}\nEOF")
    stdout.read()

    print("Fix applied!")

    # Restart backend
    print("Restarting backend...")
    client.exec_command("pkill -f 'uvicorn app.main:app'")
    import time
    time.sleep(2)
    client.exec_command("cd /root/sunkidz/backend && nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &")
    time.sleep(3)

    _, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
    status = stdout.read().decode().strip()
    print("Backend status:", "RUNNING" if "uvicorn" in status else "NOT RUNNING")
else:
    print("\nFix already applied!")

client.close()
