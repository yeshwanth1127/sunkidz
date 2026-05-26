import paramiko

HOST = "93.127.195.245"
USER = "root"
PASSWORD = "Exora@yeshwanth123"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(HOST, username=USER, password=PASSWORD, timeout=10)

print("Finding backend directory...\n")

# Find sunkidz directories
_, stdout, _ = client.exec_command("find /root -type d -name 'sunkidz' 2>/dev/null | head -10")
dirs = stdout.read().decode().strip()
print("Sunkidz directories:")
print(dirs)
print()

# Find backend directories
_, stdout, _ = client.exec_command("find /root -type d -name 'backend' 2>/dev/null | head -10")
dirs = stdout.read().decode().strip()
print("Backend directories:")
print(dirs)
print()

# Check /root structure
_, stdout, _ = client.exec_command("ls -la /root/ | grep -E 'sunkidz|app|backend'")
ls = stdout.read().decode().strip()
print("Root directory contents:")
print(ls)
print()

# Check if coordinator.py exists anywhere
_, stdout, _ = client.exec_command("find /root -name 'coordinator.py' 2>/dev/null")
files = stdout.read().decode().strip()
print("Found coordinator.py:")
print(files if files else "(not found)")

client.close()
