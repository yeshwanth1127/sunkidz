import paramiko

# 10.0.0.1 is srv956203 which has the docker containers!
PROD_HOST = "10.0.0.1"
PROD_USER = "root"
PROD_PASS = "Exora@yeshwanth123"

# We'll just run the docker exec commands directly over paramiko
# since docker is definitely installed there and running as root.

SCRIPT = r"""
set -e
echo "Starting database setup on $(hostname)..."

# 1. Create the postgres role using the n8n credentials we know work
docker exec -i postgres_prod psql -U n8n -c "CREATE ROLE postgres WITH SUPERUSER LOGIN PASSWORD 'Exora@Solutions';" || echo "Role already exists or failed"

# 2. Create the sunkidz_lms database
docker exec -i postgres_prod psql -U n8n -c "CREATE DATABASE sunkidz_lms OWNER postgres;" || echo "Database already exists"

# 3. Create the SQL setup file
cat > /tmp/sunkidz_setup.sql << 'SQLEOF'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE TABLE IF NOT EXISTS users (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), email VARCHAR(255) UNIQUE, password_hash VARCHAR(255), full_name VARCHAR(255) NOT NULL, role VARCHAR(50) NOT NULL, phone VARCHAR(50), date_of_birth DATE, profile_photo VARCHAR(500), is_active VARCHAR(10) DEFAULT 'true', onesignal_player_id VARCHAR(100), created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS branches (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(255) NOT NULL, code VARCHAR(20), address VARCHAR(500), contact_no VARCHAR(50), status VARCHAR(50) DEFAULT 'active', default_fee_due_day INTEGER DEFAULT 5, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS classes (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), branch_id UUID NOT NULL REFERENCES branches(id), name VARCHAR(255) NOT NULL, academic_year VARCHAR(20), created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS branch_assignments (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID NOT NULL REFERENCES users(id), branch_id UUID NOT NULL REFERENCES branches(id), class_id UUID REFERENCES classes(id), created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS enquiries (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), child_name VARCHAR(255) NOT NULL, date_of_birth DATE, age_years INTEGER, age_months INTEGER, gender VARCHAR(20), father_name VARCHAR(255), father_occupation VARCHAR(255), father_place_of_work VARCHAR(255), father_email VARCHAR(255), father_contact_no VARCHAR(50), mother_name VARCHAR(255), mother_occupation VARCHAR(255), mother_place_of_work VARCHAR(255), mother_email VARCHAR(255), mother_contact_no VARCHAR(50), siblings_info TEXT, siblings_age VARCHAR(100), residential_address TEXT, residential_contact_no VARCHAR(50), challenges_specialities TEXT, expectations_from_school TEXT, signature_date DATE, status VARCHAR(50) DEFAULT 'pending', branch_id UUID REFERENCES branches(id), created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS students (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), admission_number VARCHAR(50) UNIQUE NOT NULL, name VARCHAR(255) NOT NULL, date_of_birth DATE NOT NULL, age_years INTEGER, age_months INTEGER, gender VARCHAR(20), place_of_birth VARCHAR(255), nationality VARCHAR(100), mother_tongue VARCHAR(100), religion VARCHAR(100), blood_group VARCHAR(20), medical_allergies TEXT, medical_surgeries TEXT, medical_chronic_illness TEXT, class_id UUID REFERENCES classes(id), branch_id UUID REFERENCES branches(id), enquiry_id UUID REFERENCES enquiries(id), photo_path VARCHAR(500), residential_address TEXT, residential_contact_no VARCHAR(50), father_name VARCHAR(255), father_occupation VARCHAR(255), father_contact_no VARCHAR(50), father_email VARCHAR(255), mother_name VARCHAR(255), mother_occupation VARCHAR(255), mother_contact_no VARCHAR(50), mother_email VARCHAR(255), guardian_name VARCHAR(255), guardian_relation VARCHAR(100), guardian_contact_no VARCHAR(50), emergency_contact_name VARCHAR(255), emergency_contact_phone VARCHAR(50), transport_required BOOLEAN DEFAULT FALSE, bus_opted BOOLEAN DEFAULT FALSE, attended_previously BOOLEAN DEFAULT FALSE, school_daycare_name VARCHAR(255), prev_school_duration VARCHAR(100), prev_school_class VARCHAR(50), birth_certificate BOOLEAN DEFAULT FALSE, immunization_record BOOLEAN DEFAULT FALSE, transfer_certificate BOOLEAN DEFAULT FALSE, passport_photos BOOLEAN DEFAULT FALSE, progress_report BOOLEAN DEFAULT FALSE, passport BOOLEAN DEFAULT FALSE, other_medical_report BOOLEAN DEFAULT FALSE, declaration_date DATE, parent_signature_path VARCHAR(500), office_date DATE, school_rep_signature_path VARCHAR(500), created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS parent_student_links (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID NOT NULL REFERENCES users(id), student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE, is_primary BOOLEAN DEFAULT TRUE);
CREATE TABLE IF NOT EXISTS attendances (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE, date DATE NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'present', marked_by UUID REFERENCES users(id) ON DELETE SET NULL, submitted BOOLEAN NOT NULL DEFAULT FALSE, CONSTRAINT uq_attendance_student_date UNIQUE (student_id, date));
CREATE TABLE IF NOT EXISTS staff_attendances (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, date DATE NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'present', marked_by UUID REFERENCES users(id) ON DELETE SET NULL, submitted BOOLEAN NOT NULL DEFAULT FALSE, CONSTRAINT uq_staff_attendance_user_date UNIQUE (user_id, date));
CREATE TABLE IF NOT EXISTS marks_cards (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE, academic_year VARCHAR(20) NOT NULL, data JSONB, sent_to_parent_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS bus_routes (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(255) NOT NULL, description TEXT, shift VARCHAR(20) NOT NULL, branch_id UUID NOT NULL REFERENCES branches(id), bus_staff_id UUID NOT NULL REFERENCES users(id), is_active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS route_students (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), route_id UUID NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE, student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE, pickup_order INTEGER NOT NULL, pickup_address TEXT, pickup_time VARCHAR(10), created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS ride_sessions (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), route_id UUID NOT NULL REFERENCES bus_routes(id) ON DELETE CASCADE, bus_staff_id UUID NOT NULL REFERENCES users(id), start_time TIMESTAMPTZ NOT NULL, end_time TIMESTAMPTZ, status VARCHAR(20) NOT NULL DEFAULT 'active', total_distance_km FLOAT, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS location_updates (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), ride_session_id UUID NOT NULL REFERENCES ride_sessions(id) ON DELETE CASCADE, latitude FLOAT NOT NULL, longitude FLOAT NOT NULL, accuracy FLOAT, speed FLOAT, heading FLOAT, altitude FLOAT, timestamp TIMESTAMPTZ NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS daycare_groups (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), name VARCHAR(255) NOT NULL, branch_id UUID NOT NULL REFERENCES branches(id), daycare_staff_id UUID NOT NULL REFERENCES users(id), created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS daycare_group_students (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), group_id UUID NOT NULL REFERENCES daycare_groups(id) ON DELETE CASCADE, student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS daycare_daily_updates (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE, author_id UUID NOT NULL REFERENCES users(id), date DATE NOT NULL, content TEXT NOT NULL, photo_path VARCHAR(500), created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS syllabus (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), class_id UUID NOT NULL REFERENCES classes(id), uploaded_by UUID NOT NULL REFERENCES users(id), title VARCHAR(255) NOT NULL, description TEXT, upload_date DATE, school_day INTEGER, academic_year_start DATE, file_path VARCHAR(500) NOT NULL, file_name VARCHAR(255) NOT NULL, file_size VARCHAR(50), created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS homework (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), class_id UUID NOT NULL REFERENCES classes(id), uploaded_by UUID NOT NULL REFERENCES users(id), title VARCHAR(255) NOT NULL, description TEXT, upload_date DATE NOT NULL, due_date DATE, file_path VARCHAR(500) NOT NULL, file_name VARCHAR(255) NOT NULL, file_size VARCHAR(50), created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS gallery_images (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), class_id UUID NOT NULL REFERENCES classes(id), uploaded_by UUID NOT NULL REFERENCES users(id), title VARCHAR(255), description TEXT, upload_date DATE NOT NULL, file_path VARCHAR(500) NOT NULL, file_name VARCHAR(255) NOT NULL, file_size VARCHAR(50), created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS syllabus_holidays (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), academic_year_start DATE NOT NULL, holiday_date DATE NOT NULL, reason VARCHAR(255), created_by UUID REFERENCES users(id), created_at TIMESTAMPTZ DEFAULT NOW());
CREATE TABLE IF NOT EXISTS fee_structures (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), student_id UUID NOT NULL UNIQUE REFERENCES students(id) ON DELETE CASCADE, branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE, advance_fees FLOAT DEFAULT 0.0, term_fee_1 FLOAT DEFAULT 0.0, term_fee_2 FLOAT DEFAULT 0.0, term_fee_3 FLOAT DEFAULT 0.0, custom_fields_json TEXT, due_date TIMESTAMP, last_reminder_sent_at TIMESTAMP, created_at TIMESTAMP DEFAULT NOW(), updated_at TIMESTAMP DEFAULT NOW());
CREATE TABLE IF NOT EXISTS fee_payments (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), fee_structure_id UUID NOT NULL REFERENCES fee_structures(id) ON DELETE CASCADE, student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE, component VARCHAR(50) NOT NULL, amount_paid FLOAT NOT NULL, payment_mode VARCHAR(50) NOT NULL, payment_date TIMESTAMP DEFAULT NOW(), marked_by UUID REFERENCES users(id) ON DELETE SET NULL, created_at TIMESTAMP DEFAULT NOW(), updated_at TIMESTAMP DEFAULT NOW());
CREATE TABLE IF NOT EXISTS fee_receipts (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE, payment_id UUID NOT NULL REFERENCES fee_payments(id) ON DELETE CASCADE, student_name VARCHAR(255) NOT NULL, admission_number VARCHAR(100), component VARCHAR(50) NOT NULL, component_label VARCHAR(100) NOT NULL, amount_paid FLOAT NOT NULL, payment_mode VARCHAR(50) NOT NULL, payment_date TIMESTAMP, receipt_ref VARCHAR(20) NOT NULL, fee_data_json VARCHAR(4000), created_at TIMESTAMP DEFAULT NOW());
CREATE TABLE IF NOT EXISTS notifications (id UUID PRIMARY KEY DEFAULT uuid_generate_v4(), user_id UUID NOT NULL REFERENCES users(id), sender_id UUID REFERENCES users(id), title VARCHAR(255) NOT NULL, message VARCHAR(1000) NOT NULL, related_enquiry_id UUID REFERENCES enquiries(id), is_read BOOLEAN DEFAULT FALSE, created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ);
SQLEOF

# 4. Copy the script into the container and execute it
docker cp /tmp/sunkidz_setup.sql postgres_prod:/tmp/sunkidz_setup.sql
docker exec -i postgres_prod psql -U postgres -d sunkidz_lms -f /tmp/sunkidz_setup.sql

# 5. Verify tables exist
echo -e "\nVerifying tables created:"
docker exec -i postgres_prod psql -U postgres -d sunkidz_lms -c "\dt"

echo "ALL DONE!"
"""

print("Setting up DB on 10.0.0.1 (srv956203)...")
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(PROD_HOST, username=PROD_USER, password=PROD_PASS, timeout=8)

stdin, stdout, stderr = client.exec_command(SCRIPT, timeout=120)
print(stdout.read().decode())
if err := stderr.read().decode():
    print("STDERR:", err)

client.close()
