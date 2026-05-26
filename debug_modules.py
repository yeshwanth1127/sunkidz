import paramiko

HOST = "10.0.0.5"
USER = "root"
PASSWORD = "?0Ng,&0O/xJ3i,vlo'zB"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

print("=== DEBUGGING LEARNING MODULES ===\n")

try:
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    
    # Check if learning modules exist
    print("1. Checking learning modules in database...")
    _, stdout, _ = client.exec_command(
        "psql -U postgres -d sunkidz -c \"SELECT id, name, created_by FROM learning_module LIMIT 5;\" 2>/dev/null"
    )
    modules_output = stdout.read().decode()
    print(modules_output)
    
    # Check if any assignments exist
    print("\n2. Checking module assignments...")
    _, stdout, _ = client.exec_command(
        "psql -U postgres -d sunkidz -c \"SELECT COUNT(*) FROM learning_module_assignment;\" 2>/dev/null"
    )
    assignments_count = stdout.read().decode()
    print(f"Total assignments: {assignments_count}")
    
    # Test the API endpoint directly
    print("\n3. Testing API endpoint with sample student...")
    _, stdout, _ = client.exec_command(
        "curl -s 'http://localhost:8000/api/v1/learning-modules/for-student/test-student' | head -20"
    )
    api_output = stdout.read().decode()
    print(f"API Response:\n{api_output}")
    
    # Get a real student ID from the database
    print("\n4. Getting a real student ID...")
    _, stdout, _ = client.exec_command(
        "psql -U postgres -d sunkidz -c \"SELECT id FROM student LIMIT 1;\" 2>/dev/null"
    )
    student_id = stdout.read().decode().strip().split('\n')[-2] if stdout else ""
    print(f"Sample student ID: {student_id}")
    
    if student_id and student_id != "id":
        print(f"\n5. Testing API with real student ID: {student_id}")
        _, stdout, _ = client.exec_command(
            f"curl -s 'http://localhost:8000/api/v1/learning-modules/for-student/{student_id}'"
        )
        api_output = stdout.read().decode()
        print(f"API Response:\n{api_output}")
    
    client.close()

except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()
