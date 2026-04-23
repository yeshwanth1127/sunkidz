import paramiko
import bcrypt

password = "password123"
pwd_bytes = password.encode("utf-8")[:72]
hashed = bcrypt.hashpw(pwd_bytes, bcrypt.gensalt()).decode("utf-8")

sql = f"""
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin@sunkidz.com') THEN
        INSERT INTO users (email, password_hash, full_name, role, is_active)
        VALUES ('admin@sunkidz.com', '{hashed}', 'Super Admin', 'SUPER_ADMIN', 'true');
    END IF;
END $$;
"""

print("Inserting initial user via SSH to 10.0.0.1...")
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
try:
    client.connect("10.0.0.1", username="root", password="Exora@yeshwanth123", timeout=5)
    
    # Save script to remote and execute safely via stdin
    stdin, stdout, stderr = client.exec_command(f"""
cat << 'EOF' | docker exec -i postgres_prod psql -U postgres -d sunkidz_lms
{sql}
EOF
docker exec -i postgres_prod psql -U postgres -d sunkidz_lms -c "SELECT email, role FROM users;"
""", timeout=20)
    
    print(stdout.read().decode())
    print(stderr.read().decode())
    client.close()
    print("Done!")
except Exception as e:
    print(f"Failed to connect: {e}")
