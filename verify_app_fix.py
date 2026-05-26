import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("=== MOBILE APP FIX VERIFICATION ===\n")

# 1. Check if fix is in the file
print("1. Checking coordinator.py code:")
_, stdout, _ = client.exec_command("grep -A 4 'def _coordinator_branch_id' /root/sunkidz/sunkidz/backend/app/api/coordinator.py | head -6")
code = stdout.read().decode()
has_old_code = "class_id.is_(None)" in code
print(code)
print(f"Status: {'OLD CODE (broken)' if has_old_code else 'FIXED CODE (good)'}\n")

# 2. Check if backend is actually running
print("2. Backend process:")
_, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
proc = stdout.read().decode().strip()
if proc:
    print(f"RUNNING: {proc[:100]}")
else:
    print("NOT RUNNING!")

# 3. Check when backend was started
print("\n3. Backend start time:")
_, stdout, _ = client.exec_command("ps -eo pid,lstart,cmd | grep uvicorn | grep -v grep | awk '{print $2, $3, $4}'")
time = stdout.read().decode().strip()
print(time if time else "Could not determine")

client.close()

print("\n=== DIAGNOSIS ===")
if not has_old_code:
    print("Code is FIXED. If coordinator still shows 'No branch assigned':")
    print("  → Restart Flutter app (R in console)")
    print("  → Clear app cache if still broken")
    print("  → Check if Pavithra has a BranchAssignment in database")
else:
    print("CODE STILL HAS BUG! Need to restart backend!")
