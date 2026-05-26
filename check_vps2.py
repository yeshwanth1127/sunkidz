import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("=== CHECKING ALL COORDINATORS ===")
_, stdout, _ = client.exec_command("mysql -u root -p'sunkidz@123' sunkidz -e \"SELECT u.id, u.full_name, u.email, ba.branch_id, b.name FROM user u LEFT JOIN branch_assignment ba ON u.id = ba.user_id LEFT JOIN branch b ON ba.branch_id = b.id WHERE u.role = 'coordinator' LIMIT 20;\"")
print(stdout.read().decode().strip())

print("\n=== CHECKING IF BRANCH_ASSIGNMENT HAS DATA ===")
_, stdout, _ = client.exec_command("mysql -u root -p'sunkidz@123' sunkidz -e \"SELECT COUNT(*) as total_assignments FROM branch_assignment WHERE class_id IS NULL;\"")
print("Branch-level assignments: " + stdout.read().decode().strip())

_, stdout, _ = client.exec_command("mysql -u root -p'sunkidz@123' sunkidz -e \"SELECT COUNT(*) as total_assignments FROM branch_assignment WHERE class_id IS NOT NULL;\"")
print("Class-level assignments: " + stdout.read().decode().strip())

client.close()
