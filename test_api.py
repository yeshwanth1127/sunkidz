import paramiko
import json

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("=== CHECKING DATABASE DIRECTLY ===")

# Check if coordinators exist
print("\n1. All coordinators:")
cmd = "mysql -u root -p'sunkidz@123' sunkidz -N -e \"SELECT id, full_name, email, role FROM user WHERE role='coordinator' LIMIT 10;\""
_, stdout, stderr = client.exec_command(cmd)
output = stdout.read().decode().strip()
error = stderr.read().decode().strip()
print("Output:", output if output else "(empty)")
if error:
    print("Error:", error)

# Check branch assignments
print("\n2. All branch assignments:")
cmd = "mysql -u root -p'sunkidz@123' sunkidz -N -e \"SELECT COUNT(*) FROM branch_assignment;\""
_, stdout, stderr = client.exec_command(cmd)
output = stdout.read().decode().strip()
print("Total assignments:", output if output else "(empty)")

# Check branches
print("\n3. All branches:")
cmd = "mysql -u root -p'sunkidz@123' sunkidz -N -e \"SELECT id, name FROM branch LIMIT 10;\""
_, stdout, stderr = client.exec_command(cmd)
output = stdout.read().decode().strip()
print("Output:", output if output else "(empty)")

# Check users with name containing pavithra
print("\n4. Users with 'pavithra' in name:")
cmd = "mysql -u root -p'sunkidz@123' sunkidz -N -e \"SELECT id, full_name, email, role FROM user WHERE LOWER(full_name) LIKE '%pavithra%';\""
_, stdout, stderr = client.exec_command(cmd)
output = stdout.read().decode().strip()
print("Output:", output if output else "(empty)")
if error:
    print("Error:", stderr.read().decode().strip())

client.close()
