import os

input_file = r'D:\sunkidz\backend\app\api\syllabus.py.b64'
output_file = r'D:\sunkidz\backend\app\api\upload_script.sh'

with open(input_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

with open(output_file, 'w', encoding='utf-8') as f:
    f.write('echo "Starting upload..."\n')
    f.write('echo "" > /root/sunkidz/sunkidz/backend/app/api/syllabus.py.b64.remote\n')
    for line in lines:
        line = line.strip()
        if not line: continue
        # escape single quotes
        line = line.replace("'", "'\\''")
        f.write(f"echo '{line}' >> /root/sunkidz/sunkidz/backend/app/api/syllabus.py.b64.remote\n")
    f.write('echo "Upload complete."\n')
