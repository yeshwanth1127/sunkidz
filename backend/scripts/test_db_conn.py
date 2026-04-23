import paramiko

def test_db_connection():
    print(f"Testing DB connection directly from 10.0.0.5...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect("10.0.0.5", username="root", password="?0Ng,&0O/xJ3i,vlo'zB", timeout=5)
        
        # Create a tiny python script on the remote host to test connection
        test_script = """
import os
from sqlalchemy import create_engine
url = 'postgresql://postgres:Exora@Solutions@93.127.195.245:5432/sunkidz_lms'
print('Testing direct connect without URL encoding...')
try:
    engine = create_engine(url)
    engine.connect()
    print('SUCCESS without encoding!')
except Exception as e:
    print('FAILED:', e)

url2 = 'postgresql://postgres:Exora%40Solutions@93.127.195.245:5432/sunkidz_lms'
print('Testing connect with URL encoding...')
try:
    engine2 = create_engine(url2)
    engine2.connect()
    print('SUCCESS with encoding!')
except Exception as e:
    print('FAILED encoding:', e)
"""
        stdin, stdout, stderr = client.exec_command(f"""
cat > /tmp/test_db.py << 'EOF'
{test_script}
EOF
/root/sunkidz/sunkidz/backend/venv/bin/python /tmp/test_db.py || python3 /tmp/test_db.py
""", timeout=20)
        
        print("--- TEST DB CONNECTION ---")
        print(stdout.read().decode())
        print(stderr.read().decode())
        
        client.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

test_db_connection()
