import paramiko

def restart_backend(host, user, pw):
    print(f"Restarting backend on {host}...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username=user, password=pw, timeout=5)
        stdin, stdout, stderr = client.exec_command(
            "pm2 restart all || systemctl restart sunkidz", 
            timeout=15
        )
        print(stdout.read().decode())
        print(stderr.read().decode())
        client.close()
        print("Backend successfully restarted!")
    except Exception as e:
        print(f"Failed to connect to {host}: {e}")

restart_backend("10.0.0.5", "root", "?0Ng,&0O/xJ3i,vlo'zB")
