import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("=== CHECKING BACKEND .ENV ===")
_, stdout, _ = client.exec_command("cat /root/sunkidz/sunkidz/backend/.env | grep -i database")
env_output = stdout.read().decode().strip()
print(env_output)

print("\n=== LISTING DATABASES ===")
_, stdout, _ = client.exec_command("mysql -u root -p'sunkidz@123' -e 'SHOW DATABASES;'")
db_list = stdout.read().decode().strip()
print(db_list)

print("\n=== CHECKING BACKEND CODE FOR DB NAME ===")
_, stdout, _ = client.exec_command("grep -r 'database' /root/sunkidz/sunkidz/backend/app/core/ | grep -v '.pyc'")
code = stdout.read().decode().strip()
print(code[:500])

client.close()
