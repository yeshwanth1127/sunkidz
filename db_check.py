import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    print("1. Checking database configuration...")
    _, stdout, _ = client.exec_command(f"grep -E 'DATABASE_URL|postgres' {backend_dir}/app/core/config.py 2>/dev/null | head -5")
    config = stdout.read().decode()
    print(f"   Config:\n{config}")
    
    print("2. Checking .env file...")
    _, stdout, _ = client.exec_command("cat /root/.env 2>/dev/null | head -5")
    env = stdout.read().decode()
    print(f"   .env: {env[:100]}")
    
    print("3. Checking if database is accessible...")
    _, stdout, _ = client.exec_command("netstat -tuln | grep 5432")
    netstat = stdout.read().decode()
    print(f"   Port 5432: {netstat[:100] if netstat else 'Not listening locally'}")
    
    print("4. Checking if postgres process running...")
    _, stdout, _ = client.exec_command("ps aux | grep postgres")
    ps = stdout.read().decode()
    print(f"   Postgres: {('Running' if 'postgres' in ps and grep not in ps else 'Not running')}")
    
    print("\n5. Reading actual database URL being used...")
    _, stdout, _ = client.exec_command(f"cd {backend_dir} && python3 -c \"from app.core import config; print(f'DB_URL: {{config.settings.database_url}}')\" 2>&1")
    dburl = stdout.read().decode()
    print(f"   {dburl}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
