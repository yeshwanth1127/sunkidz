import paramiko

def force_restart_pm2():
    print("Restarting PM2 with --update-env on 10.0.0.5...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect("10.0.0.5", username="root", password="?0Ng,&0O/xJ3i,vlo'zB", timeout=5)
        # Force reload of environment variables
        stdin, stdout, stderr = client.exec_command(
            "cd /root/sunkidz/sunkidz/backend && source venv/bin/activate && pm2 restart sunkidz-api --update-env", 
            timeout=15
        )
        print(stdout.read().decode())
        
        # Check logs after that
        stdin, stdout, stderr = client.exec_command("sleep 3 && pm2 logs sunkidz-api --lines 15 --nostream", timeout=15)
        print("--- PM2 LOGS ---")
        print(stdout.read().decode())
        client.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

force_restart_pm2()
