import paramiko

def check_nginx():
    print("Checking Nginx on 10.0.0.5...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect("10.0.0.5", username="root", password="?0Ng,&0O/xJ3i,vlo'zB", timeout=5)
        stdin, stdout, stderr = client.exec_command("cat /etc/nginx/sites-enabled/* | grep server_name", timeout=15)
        print("SERVERS:")
        print(stdout.read().decode())
        client.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

check_nginx()
