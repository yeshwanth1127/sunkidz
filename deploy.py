import paramiko, sys, time

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("10.0.0.5", username="root", password="?0Ng,&0O/xJ3i,vlo'zB", timeout=20)

sftp = c.open_sftp()
sftp.put(r"d:/sunkidz/backend/app/schemas/admin.py", "/root/sunkidz/sunkidz/backend/app/schemas/admin.py")
sftp.put(r"d:/sunkidz/backend/app/models/branch.py", "/root/sunkidz/sunkidz/backend/app/models/branch.py")
sftp.put(r"d:/sunkidz/backend/app/api/admin.py", "/root/sunkidz/sunkidz/backend/app/api/admin.py")
sftp.close()
print("Files uploaded")

_, o, _ = c.exec_command("pm2 restart sunkidz-api")
o.channel.recv_exit_status()
time.sleep(6)

_, o, _ = c.exec_command("tail -20 /root/sunkidz/sunkidz/backend/logs/pm2-error.log")
err = o.read().decode("utf-8", errors="replace")

_, o, _ = c.exec_command("tail -10 /root/sunkidz/sunkidz/backend/logs/pm2-out.log")
out = o.read().decode("utf-8", errors="replace")

c.close()
print("OUT:", out)
print("ERRORS:", err[-2000:])
