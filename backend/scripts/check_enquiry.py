import paramiko

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect("10.0.0.1", username="root", password="Exora@yeshwanth123", timeout=5)

# First check the actual columns
cmd1 = """docker exec -i postgres_prod psql -U postgres -d sunkidz_lms -c "\\d enquiries" """
stdin, stdout, stderr = client.exec_command(cmd1, timeout=15)
print("TABLE STRUCTURE:")
print(stdout.read().decode())

# Then select all data
cmd2 = """docker exec -i postgres_prod psql -U postgres -d sunkidz_lms -x -c "SELECT * FROM enquiries ORDER BY created_at DESC LIMIT 5;" """
stdin, stdout, stderr = client.exec_command(cmd2, timeout=15)
print("ENQUIRY DATA:")
print(stdout.read().decode())

client.close()
