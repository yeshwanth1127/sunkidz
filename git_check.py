import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Git status...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git status")
    print(stdout.read().decode()[:300])
    
    print("\n2. Git log (last 3 commits)...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git log --oneline -3")
    print(stdout.read().decode())
    
    print("\n3. Git branch...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git branch")
    print(stdout.read().decode())
    
    print("\n4. Checking local vs remote...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && git fetch && git log --oneline -3 origin/master")
    print(stdout.read().decode())
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
