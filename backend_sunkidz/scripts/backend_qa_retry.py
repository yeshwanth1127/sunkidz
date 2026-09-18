import paramiko

def check_backend_health():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    # Try both common passwords
    passwords = ["Exora@yeshwanth123", "Exora@Solutions"]
    for pwd in passwords:
        try:
            client.connect("10.0.0.5", username="root", password=pwd, timeout=5)
            print(f"--- SUCCESS WITH PWD ({pwd[:3]}...) ---")
            
            print("--- PM2 API LOGS (Last 50 lines) ---")
            stdin, stdout, stderr = client.exec_command('pm2 logs sunkidz-api --lines 50 --nostream', timeout=15)
            print(stdout.read().decode())
            
            print("\n--- PM2 APP STATUS ---")
            stdin, stdout, stderr = client.exec_command('pm2 status', timeout=5)
            print(stdout.read().decode())
            
            client.close()
            return
        except Exception as e:
            print(f"Failed with {pwd[:3]}: {e}")

if __name__ == "__main__":
    check_backend_health()
