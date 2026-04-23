import sys
try:
    import paramiko
except:
    import subprocess
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'paramiko', '-q'])
    import paramiko

def run(host, password, cmd):
    print(f"\n--- Running on {host} ---")
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(host, username='root', password=password, timeout=10)
        stdin, stdout, stderr = ssh.exec_command(cmd)
        print(stdout.read().decode(errors='replace'))
        print(stderr.read().decode(errors='replace'))
    except Exception as e:
        print(f"Failed {host}: {e}")
    finally:
        ssh.close()

# 10.0.0.1 is supposed to be "postgres tables" but let's check code too
run("10.0.0.1", "Exora@yeshwanth123", "ls -la /var/www/sunkidz || echo 'No sunkidz folder on 10.0.0.1'")

# 10.0.0.5 is APP BACKEND
run("10.0.0.5", "?0Ng,&0O/xJ3i,vlo'zB", "ls -la /var/www/sunkidz || echo 'No sunkidz folder on 10.0.0.5'")
