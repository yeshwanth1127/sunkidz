import paramiko
import sys

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

try:
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    print("Connected to " + HOST)

    # 1. Check backend status
    print("\n=== CHECKING BACKEND STATUS ===")
    _, stdout, _ = client.exec_command("ps aux | grep uvicorn | grep -v grep")
    backend_status = stdout.read().decode().strip()
    print(backend_status if backend_status else "[ERROR] Backend not running")

    # 2. Check coordinator.py for my fix
    print("\n=== CHECKING CODE FIX ===")
    _, stdout, _ = client.exec_command("cat /root/sunkidz/backend/app/api/coordinator.py | grep -A 5 '_coordinator_branch_id'")
    code = stdout.read().decode().strip()
    if "class_id.is_(None)" in code:
        print("[OLD CODE] Still has class_id filter")
    else:
        print("[NEW CODE] Filter removed!")
    print(code)

    # 3. Check Pavithra's assignment
    print("\n=== CHECKING PAVITHRA DATABASE RECORD ===")
    _, stdout, _ = client.exec_command("mysql -u root -p'sunkidz@123' sunkidz -e \"SELECT ba.id, ba.user_id, u.full_name, ba.branch_id, b.name as branch_name, ba.class_id FROM branch_assignment ba JOIN `user` u ON ba.user_id = u.id LEFT JOIN branch b ON ba.branch_id = b.id WHERE u.full_name LIKE '%Pavithra%';\"")
    result = stdout.read().decode().strip()
    print(result)

    client.close()
    print("\n[SUCCESS] Check complete")

except Exception as e:
    print("[ERROR] " + str(e))
    sys.exit(1)
