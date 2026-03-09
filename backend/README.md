# Preschool LMS Backend

FastAPI backend with PostgreSQL, JWT auth, and SQLAlchemy.

## Setup

1. **PostgreSQL** – ensure it is running locally. Create the database:
   ```bash
   psql -U postgres -c "CREATE DATABASE sunkidz_lms;"
   ```

2. **Copy `.env.example` to `.env`** and set your `DATABASE_URL`.

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Create database if missing**:
   ```bash
   python -m scripts.create_db_if_missing
   ```

5. **Create tables**:
   ```bash
   python -m scripts.init_db
   ```
   (Or use `python -m scripts.migrate` if alembic is installed)

6. **Seed admin user**:
   ```bash
   python -m scripts.seed_admin
   ```

7. **Start server**:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 9889
   ```

## API

- **Docs**: http://localhost:9889/docs
- **Health**: http://localhost:9889/health

## Auth

**Staff login** (POST `/api/v1/auth/login`):
```json
{"email": "admin@sunkidz.com", "password": "admin123"}
```

**Parent login** (POST `/api/v1/auth/login`):
```json
{"admission_number": "SK-2025-001", "date_of_birth": "2020-05-12"}
```

**Protected routes**: Add header `Authorization: Bearer <token}`

## Default users (after seed)

| Email | Password | Role |
|-------|----------|------|
| admin@sunkidz.com | admin123 | admin |
| coord@sunkidz.com | coord123 | coordinator |
| teacher@sunkidz.com | teacher123 | teacher |

**Coordinator credentials** (demo): `coord@sunkidz.com` / `coord123` — created by `python -m scripts.seed_admin`.

**Admin-created coordinators**: Admins create coordinators via **Staff** → **Coordinators** tab → **Add**. Each coordinator needs: name, email, password, and branch assignment. They log in with email + password.
