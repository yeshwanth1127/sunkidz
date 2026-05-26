import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    backend_dir = "/root/sunkidz/sunkidz/backend"
    
    # Read the file content
    _, stdout, _ = client.exec_command(f"cat {backend_dir}/app/api/learning_modules.py")
    content = stdout.read().decode()
    
    # Count lines with router.get/post/delete
    lines = content.split('\n')
    print("File routes:")
    for i, line in enumerate(lines, 1):
        if '@router.' in line:
            print(f"  Line {i}: {line.strip()}")
    
    print(f"\nTotal lines: {len(lines)}")
    print(f"File has 'for-student'?: {'for-student' in content}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
