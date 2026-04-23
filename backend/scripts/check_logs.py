import paramiko

def check_backend_logs(host, user, pw):
    print(f"Checking PM2 logs on {host}...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, username=user, password=pw, timeout=5)
        # Check pm2 logs for sunkidz-api
        stdin, stdout, stderr = client.exec_command(
            "pm2 logs sunkidz-api --lines 15 --nostream", 
            timeout=15
        )
        print("--- PM2 LOGS ---")
        print(stdout.read().decode())
        
        # Check pm2 status
        stdin, stdout, stderr = client.exec_command(
            "pm2 jlist", 
            timeout=15
        )
        import json
        try:
            data = json.loads(stdout.read().decode())
            for app in data:
                print(f"App: {app['name']}, Status: {app['pm2_env']['status']}")
        except:
            print("Failed to parse PM2 jlist")
            
        client.close()
    except Exception as e:
        print(f"Failed to connect to {host}: {e}")

check_backend_logs("10.0.0.5", "root", "?0Ng,&0O/xJ3i,vlo'zB")
