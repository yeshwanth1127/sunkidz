import paramiko

def fix_admin_role():
    print("Fixing admin role in DB on 10.0.0.1...")
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect("10.0.0.1", username="root", password="Exora@yeshwanth123", timeout=5)
        
        # Save script to remote and execute safely via stdin
        stdin, stdout, stderr = client.exec_command(f"""
cat << 'EOF' | docker exec -i postgres_prod psql -U postgres -d sunkidz_lms
UPDATE users SET role = 'admin' WHERE email = 'admin@sunkidz.com';
EOF
docker exec -i postgres_prod psql -U postgres -d sunkidz_lms -c "SELECT email, role FROM users;"
""", timeout=20)
        
        print(stdout.read().decode())
        print(stderr.read().decode())
        client.close()
        print("Done!")
    except Exception as e:
        print(f"Failed to connect: {e}")

fix_admin_role()
