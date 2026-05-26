import paramiko

HOSTS = [
    ("10.0.0.5", "10.0.0.5"),
    ("10.0.0.1", "10.0.0.1"),
]

USER = "root"
PASSWORD = "Exora@yeshwanth123"

print("Looking for Sunkidz backend...\n")

for host, label in HOSTS:
    print(f"=== {label} ===")
    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(host, username=USER, password=PASSWORD, timeout=5)

        # Find sunkidz directories
        _, stdout, _ = client.exec_command("find /root -type d -name '*sunkidz*' 2>/dev/null | head -5")
        dirs = stdout.read().decode().strip()
        if dirs:
            print("Sunkidz paths found:")
            print(dirs)

        # Find coordinator.py
        _, stdout, _ = client.exec_command("find /root -name 'coordinator.py' -path '*/app/api/*' 2>/dev/null")
        files = stdout.read().decode().strip()
        if files:
            print("Coordinator files:")
            print(files)

        # Check if backend is running
        _, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep | head -2")
        procs = stdout.read().decode().strip()
        if procs:
            print("Backend running on:", procs[:100])

        client.close()
        print()

    except Exception as e:
        print(f"Could not connect: {e}\n")

print("\n=== CHECKING WHAT 31.97.63.193 / api.sunkidz.org IS ===")
print("Hostname lookup: api.sunkidz.org = 31.97.63.193 (not accessible via SSH)")
print("This appears to be a cloud/managed server without SSH access")
