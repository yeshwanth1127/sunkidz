import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=5)

print("=== CHECKING COORDINATOR FIX ON 10.0.0.5 ===\n")

# Read the function
_, stdout, _ = client.exec_command("sed -n '21,30p' /root/sunkidz/sunkidz/backend/app/api/coordinator.py")
code = stdout.read().decode()

print("Current code in _coordinator_branch_id function:")
print(code)
print()

if "class_id.is_(None)" in code:
    print("STATUS: OLD CODE - has class_id filter (needs fix)")
else:
    print("STATUS: NEW CODE - filter removed (fix is applied)")

# Check database for coordinators
print("\n=== DATABASE CHECK ===")
print("Checking what data exists in the database...")
_, stdout, _ = client.exec_command("cd /root/sunkidz/sunkidz/backend && python -c \"from app.core.database import SessionLocal; from app.models import User; db = SessionLocal(); users = db.query(User).filter(User.role=='coordinator').all(); print(f'Coordinators: {len(users)}'); [print(f'  - {u.full_name}') for u in users]\" 2>&1")
output = stdout.read().decode().strip()
print(output)

client.close()
