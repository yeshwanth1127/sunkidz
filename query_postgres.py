import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("=== QUERYING POSTGRESQL DATABASE ===")

# Query using psql from the VPS
cmd = "PGPASSWORD='ExoraSolutions@2004' psql -h 31.97.63.193 -U sunkidz_user -d sunkidz_lms -c \"SELECT id, full_name, email, role FROM \\\"user\\\" WHERE LOWER(full_name) LIKE '%pavithra%';\""
_, stdout, stderr = client.exec_command(cmd)
output = stdout.read().decode().strip()
error = stderr.read().decode().strip()
print("1. User Pavithra:")
print(output if output else "(not found)")
if error and "FATAL" in error:
    print("DB Error:", error)

print("\n2. Check branch_assignment table:")
cmd = "PGPASSWORD='ExoraSolutions@2004' psql -h 31.97.63.193 -U sunkidz_user -d sunkidz_lms -c \"SELECT COUNT(*) FROM branch_assignment;\""
_, stdout, _ = client.exec_command(cmd)
output = stdout.read().decode().strip()
print("Total branch assignments:", output.split('\n')[-2] if output else "(empty)")

print("\n3. Check all coordinators:")
cmd = "PGPASSWORD='ExoraSolutions@2004' psql -h 31.97.63.193 -U sunkidz_user -d sunkidz_lms -c \"SELECT id, full_name, role FROM \\\"user\\\" WHERE role='coordinator' LIMIT 10;\""
_, stdout, _ = client.exec_command(cmd)
output = stdout.read().decode().strip()
print(output if output else "(empty)")

client.close()
