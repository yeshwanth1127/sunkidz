import paramiko

def check_backend(host, user, pw):
    print(f"Checking for Sunkidz backend on {host}...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username=user, password=pw, timeout=5)
        stdin, stdout, stderr = client.exec_command(
            "pm2 list 2>/dev/null; echo '---'; find /root /home /opt /var/www -name '.env' -type f 2>/dev/null | xargs grep -l sunkidz 2>/dev/null", 
            timeout=15
        )
        print(stdout.read().decode())
        client.close()
    except Exception as e:
        print(f"Failed to connect to {host}: {e}")

check_backend("10.0.0.5", "root", "?0Ng,&0O/xJ3i,vlo'zB")
