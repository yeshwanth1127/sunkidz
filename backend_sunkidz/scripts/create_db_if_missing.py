"""Create the configured PostgreSQL database if it does not exist.

Usage:
  python -m scripts.create_db_if_missing
"""

import sys
from pathlib import Path

import psycopg2
from psycopg2 import sql
from psycopg2 import OperationalError
from sqlalchemy.engine import make_url

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings


def main() -> None:
    db_url = settings.database_url
    url = make_url(db_url)

    if not str(url.drivername).startswith("postgresql"):
        raise RuntimeError("create_db_if_missing supports only PostgreSQL URLs")

    db_name = url.database
    if not db_name:
        raise RuntimeError("DATABASE_URL must include a database name")

    connect_kwargs = {
        "host": url.host or "localhost",
        "port": int(url.port or 5432),
        "user": url.username,
        "password": url.password,
        "dbname": "postgres",
    }

    conn = None
    try:
        conn = psycopg2.connect(**connect_kwargs)
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (db_name,))
            exists = cur.fetchone() is not None

            if exists:
                print(f"Database '{db_name}' already exists")
                return

            cur.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(db_name)))
            print(f"Database '{db_name}' created")
    except OperationalError as exc:
        raise RuntimeError(
            "Unable to connect to PostgreSQL with credentials from DATABASE_URL"
        ) from exc
    finally:
        if conn is not None:
            conn.close()


if __name__ == "__main__":
    main()
