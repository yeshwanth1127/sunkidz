import paramiko
import time

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("=== APPLYING FIX TO 10.0.0.5 ===\n")

# Read the file
print("1. Reading coordinator.py...")
_, stdout, _ = client.exec_command("cat /root/sunkidz/sunkidz/backend/app/api/coordinator.py")
content = stdout.read().decode()

# Replace the problematic lines
print("2. Removing class_id.is_(None) filter...")
new_content = content.replace(
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
print("3. Writing fixed file...")
_, stdout, _ = client.exec_command(f"cat > /root/sunkidz/sunkidz/backend/app/api/coordinator.py << 'EOFFIX'\n{new_content}\nEOFFIX")
stdout.read()

# Verify
print("4. Verifying fix...")
_, stdout, _ = client.exec_command("grep -A 3 '_coordinator_branch_id' /root/sunkidz/sunkidz/backend/app/api/coordinator.py | head -5")
fixed_code = stdout.read().decode().strip()
if "class_id.is_(None)" in fixed_code:
    print("   ERROR: Fix did not apply!")
    print(fixed_code)
else:
    print("   SUCCESS: class_id filter removed!")

# Restart backend
print("\n5. Restarting backend...")
client.exec_command("pkill -f 'uvicorn app.main:app'")
time.sleep(2)
client.exec_command("cd /root/sunkidz/sunkidz/backend && nohup /root/sunkidz/sunkidz/backend/venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8001 > /tmp/backend.log 2>&1 &")
time.sleep(3)

# Verify backend is running
print("6. Verifying backend...")
_, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
status = stdout.read().decode().strip()
if "uvicorn" in status:
    print("   SUCCESS: Backend restarted!")
else:
    print("   ERROR: Backend not running!")

client.close()

print("\n=== DONE ===")
print("Backend on 10.0.0.5 has been fixed and restarted!")
print("Now hot reload the Flutter app (press R in the console)")
