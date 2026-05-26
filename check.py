import paramiko, sys, time

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("10.0.0.5", username="root", password="?0Ng,&0O/xJ3i,vlo'zB", timeout=20)

def run(cmd):
    _, o, _ = c.exec_command(cmd)
    return o.read().decode("utf-8", errors="replace")

schema = run("grep -n 'system_type\\|branch_type' /root/sunkidz/sunkidz/backend/app/schemas/admin.py")
model  = run("grep -n 'system_type\\|branch_type' /root/sunkidz/sunkidz/backend/app/models/branch.py")
err    = run("tail -30 /root/sunkidz/sunkidz/backend/logs/pm2-error.log")
pid    = run("pm2 pid sunkidz-api")
restarts = run("pm2 show sunkidz-api 2>&1 | grep -E 'restart|status|pid'")

c.close()

out = f"SCHEMA:\n{schema}\nMODEL:\n{model}\nPID: {pid}\nRESTARTS:\n{restarts}\nERRORS:\n{err}"
sys.stdout.buffer.write(out.encode("utf-8"))
