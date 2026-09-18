import paramiko

def check_backend_health():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        # Check logs on 10.0.0.5 (API Server)
        print("Connecting to API Server on 10.0.0.5...")
        client.connect("10.0.0.5", username="root", password="?0Ng,&0O/xJ3i,vlo'zB", timeout=5)
        
        print("--- PM2 API LOGS (Last 50 lines) ---")
        stdin, stdout, stderr = client.exec_command('pm2 logs sunkidz-api --lines 50 --nostream', timeout=15)
        print(stdout.read().decode())
        
        print("\n--- PM2 APP STATUS ---")
        stdin, stdout, stderr = client.exec_command('pm2 status', timeout=5)
        print(stdout.read().decode())
        
        client.close()
    except Exception as e:
        print(f"Failed to connect to backend: {e}")

if __name__ == "__main__":
    check_backend_health()
