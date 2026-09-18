import paramiko

def read_backend_env():
    print("Reading .env on 10.0.0.5...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect("10.0.0.5", username="root", password="?0Ng,&0O/xJ3i,vlo'zB", timeout=5)
        stdin, stdout, stderr = client.exec_command("cat /root/sunkidz/sunkidz/backend/.env", timeout=15)
        print(stdout.read().decode())
        client.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

read_backend_env()
