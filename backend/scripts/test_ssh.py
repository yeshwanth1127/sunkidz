import paramiko
import sys

def test_ssh(host, username, passwords):
    print(f"Testing SSH to {host} as {username}...")
    for pw in passwords:
        client = paramiko.SSHClient()
        client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        try:
            print(f"Trying password: {pw}")
            client.connect(host, username=username, password=pw, timeout=5)
            print(f"✅ SUCCESS! Connected to {host} with password {pw}")
            
            # Check hostname and docker
            stdin, stdout, stderr = client.exec_command("hostname; echo '---'; docker ps 2>/dev/null || echo 'No docker'")
            print(stdout.read().decode())
            client.close()
            return
        except Exception as e:
            print(f"❌ Failed: {e}")

passwords = ["Exora@yeshwanth123", "?0Ng,&0O/xJ3i,vlo'zB", "Exora@Solutions"]
test_ssh("93.127.195.245", "root", passwords)
test_ssh("10.0.0.1", "root", passwords)
