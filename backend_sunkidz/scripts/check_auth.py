import paramiko

def check_db_auth():
    print(f"Checking pg_hba.conf on 10.0.0.1...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect("10.0.0.1", username="root", password="Exora@yeshwanth123", timeout=5)
        # Check pg_hba.conf in the container
        stdin, stdout, stderr = client.exec_command(
            "docker exec -i postgres_prod psql -U postgres -d sunkidz_lms -c 'SHOW hba_file;'", 
            timeout=15
        )
        hba_file = stdout.read().decode().strip().split('\n')[2].strip()
        print("HBA File:", hba_file)
        
        stdin, stdout, stderr = client.exec_command(
            f"docker exec -i postgres_prod cat {hba_file} | grep -v '^#'", 
            timeout=15
        )
        print("--- pg_hba.conf ---")
        print(stdout.read().decode())
        
        # also test connecting from 10.0.0.5 directly using postgres client
        client.close()
    except Exception as e:
        print(f"Failed to connect: {e}")

check_db_auth()
