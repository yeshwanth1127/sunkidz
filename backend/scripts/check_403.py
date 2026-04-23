import paramiko

def check_pm2_logs():
    print("Checking PM2 logs for 403 errors on 10.0.0.5...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect("10.0.0.5", username="root", password="?0Ng,&0O/xJ3i,vlo'zB", timeout=5)
        # Fetch last 100 lines to see endpoints returning 403
        stdin, stdout, stderr = client.exec_command("pm2 logs sunkidz-api --lines 100 --nostream", timeout=15)
        print("--- PM2 LOGS ---")
        logs = stdout.read().decode()
        for line in logs.split('\n'):
            if "403" in line or "Exception" in line or "error" in line.lower() or "forbidden" in line.lower():
                print(line.strip())
        print("--- END FILTERED LOGS ---")
        client.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

check_pm2_logs()
