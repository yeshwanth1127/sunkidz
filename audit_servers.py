import paramiko

HOSTS = [
    ("10.0.0.5", "10.0.0.5 (Staging)"),
    ("93.127.195.245", "93.127.195.245 (Backup)"),
]

USER = "root"
PASSWORD = "Exora@yeshwanth123"

for host, label in HOSTS:
    print(f"\n{'='*60}")
    print(f"{label}")
    print('='*60)

    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(host, username=USER, password=PASSWORD, timeout=5)

        # List what's in /root
        print("\n1. Root directories:")
        _, stdout, _ = client.exec_command("ls -d /root/*/ 2>/dev/null | head -10")
        print(stdout.read().decode().strip())

        # Check if sunkidz exists
        print("\n2. Sunkidz backend location:")
        _, stdout, _ = client.exec_command("ls -la /root/sunkidz/ 2>/dev/null | head -5")
        sunkidz_ls = stdout.read().decode().strip()
        if sunkidz_ls:
            print(sunkidz_ls)
        else:
            print("(No /root/sunkidz found)")

        # Check for coordinator.py
        print("\n3. Coordinator.py location:")
        _, stdout, _ = client.exec_command("find /root -name 'coordinator.py' 2>/dev/null")
        coord_path = stdout.read().decode().strip()
        if coord_path:
            print(f"Found at: {coord_path}")
            # Read first 20 lines of the function
            _, stdout, _ = client.exec_command(f"sed -n '20,30p' {coord_path}")
            print("Content preview:")
            print(stdout.read().decode().strip()[:300])
        else:
            print("(Not found)")

        # Check what's running
        print("\n4. Running processes:")
        _, stdout, _ = client.exec_command("ps aux | grep -E 'uvicorn|python.*app' | grep -v grep")
        procs = stdout.read().decode().strip()
        if procs:
            for line in procs.split('\n')[:2]:
                print(line[:120])
        else:
            print("(No backend running)")

        # Check .env for API config
        print("\n5. Backend .env database URL:")
        _, stdout, _ = client.exec_command("find /root -name '.env' -path '*/backend/*' -exec grep DATABASE_URL {} \;")
        env = stdout.read().decode().strip()
        if env:
            # Mask password
            import re
            masked = re.sub(r'(://[^:]+:)[^@]+(@)', r'\1***\2', env)
            print(masked)
        else:
            print("(No .env found)")

        client.close()

    except Exception as e:
        print(f"ERROR: {e}")

print("\n" + "="*60)
print("SUMMARY")
print("="*60)
print("Check which server has the active Sunkidz backend")
print("(Look for running uvicorn process on the correct port)")
