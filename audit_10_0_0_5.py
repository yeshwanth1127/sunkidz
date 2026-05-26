import paramiko

HOST = "10.0.0.5"
USER = "root"

# Try both passwords
passwords = [
    ("?0Ng,&0O/xJ3i,vlo'zB", "Old password from deploy script"),
    ("Exora@yeshwanth123", "New password you provided"),
]

for pwd, pwd_label in passwords:
    print(f"\nTrying: {pwd_label}")
    print("-" * 50)

    try:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        client.connect(HOST, username=USER, password=pwd, timeout=5)
        print("[OK] Connected!")

        # Check sunkidz backend
        _, stdout, _ = client.exec_command("ls -la /root/ | grep sunkidz")
        ls = stdout.read().decode().strip()
        print(f"Sunkidz dirs: {ls if ls else '(none)'}")

        # Check coordinator.py
        _, stdout, _ = client.exec_command("find /root -name 'coordinator.py' 2>/dev/null | head -1")
        coord = stdout.read().decode().strip()
        if coord:
            print(f"Coordinator.py: {coord}")

        # Check running backend
        _, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
        procs = stdout.read().decode().strip()
        if procs:
            print("Backend RUNNING:")
            print(procs[:150])
        else:
            print("Backend: NOT running")

        client.close()
        break

    except Exception as e:
        print(f"[FAIL] Failed: {e}")

print("\n" + "="*50)
print("Results above - which server should I update?")
