import psycopg2
passwords = ['ExoraSolutions@2004', 'ExoraSolutions2004', 'postgres', 'admin', 'root']
for pw in passwords:
    try:
        conn = psycopg2.connect(f'postgresql://postgres:{pw}@localhost:5432/postgres')
        print(f"Success with password: '{pw}'")
        conn.close()
        break
    except Exception as e:
        pass
else:
    print("Failed all passwords")
