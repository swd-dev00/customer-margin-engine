import os
import uuid
from pathlib import Path

import pytest

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="session")
def postgres_connection():
    database_url = os.getenv("TEST_DATABASE_URL")
    if not database_url:
        pytest.skip("TEST_DATABASE_URL is not configured")

    psycopg = pytest.importorskip("psycopg")
    from psycopg import sql

    connection = psycopg.connect(database_url, autocommit=True)
    schema_name = f"margin_test_{uuid.uuid4().hex}"
    schema_identifier = sql.Identifier(schema_name)

    connection.execute(
        sql.SQL("CREATE SCHEMA {}").format(schema_identifier),
    )
    connection.execute(
        sql.SQL("SET search_path TO {}, public").format(schema_identifier),
    )

    try:
        for schema_file in sorted(
            (REPOSITORY_ROOT / "schema").glob("[0-9][0-9]_*.sql")
        ):
            connection.execute(
                schema_file.read_text(encoding="utf-8"),
                prepare=False,
            )

        for fixture_name in ("base.sql", "revenue.sql", "costs.sql", "allocation.sql"):
            fixture_file = (
                REPOSITORY_ROOT / "tests" / "fixtures" / "golden" / fixture_name
            )
            connection.execute(
                fixture_file.read_text(encoding="utf-8"),
                prepare=False,
            )

        yield connection
    finally:
        connection.execute("SET search_path TO public")
        connection.execute(
            sql.SQL("DROP SCHEMA {} CASCADE").format(schema_identifier),
        )
        connection.close()
