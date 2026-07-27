import json
import re
from pathlib import Path

import pytest

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
SCHEMA_DIRECTORY = REPOSITORY_ROOT / "schema"
SCHEMA_FILES = sorted(SCHEMA_DIRECTORY.glob("[0-9][0-9]_*.sql"))


def test_schema_slices_are_complete_and_ordered() -> None:
    expected_prefixes = [f"{number:02d}" for number in range(1, 14)]
    actual_prefixes = [path.name.split("_", maxsplit=1)[0] for path in SCHEMA_FILES]

    assert actual_prefixes == expected_prefixes


def test_version_manifest_matches_committed_schema_files() -> None:
    manifest = json.loads(
        (REPOSITORY_ROOT / "migrations/versions.json").read_text(encoding="utf-8")
    )
    expected_files = [
        path.relative_to(REPOSITORY_ROOT).as_posix() for path in SCHEMA_FILES
    ]

    assert manifest["latest_slice"] == 13
    assert manifest["files"] == expected_files


@pytest.mark.parametrize("schema_file", SCHEMA_FILES, ids=lambda path: path.name)
def test_financial_ddl_avoids_inexact_money_types(schema_file: Path) -> None:
    ddl = schema_file.read_text(encoding="utf-8")

    assert re.search(r"\b(?:REAL|MONEY|DOUBLE\s+PRECISION)\b", ddl, re.I) is None


def test_currency_columns_are_required_text_values() -> None:
    currency_columns = []
    for schema_file in SCHEMA_FILES:
        for line in schema_file.read_text(encoding="utf-8").splitlines():
            if re.match(r"\s+\w*currency\s+", line, re.I):
                currency_columns.append((schema_file.name, line.strip()))

    assert currency_columns
    assert all(
        re.search(r"\bTEXT\s+NOT\s+NULL\b", declaration, re.I)
        for _, declaration in currency_columns
    )


def test_partial_active_run_constraint_is_a_postgresql_index() -> None:
    ddl = (SCHEMA_DIRECTORY / "07_calculation_runs.sql").read_text(encoding="utf-8")

    assert "CREATE UNIQUE INDEX uq_calculation_runs_active" in ddl
    assert re.search(r"UNIQUE\s*\([^;]+\)\s+WHERE", ddl, re.I | re.S) is None


def test_raw_evidence_has_database_enforced_append_only_triggers() -> None:
    ddl = (SCHEMA_DIRECTORY / "13_raw_evidence_immutability.sql").read_text(
        encoding="utf-8"
    )

    assert "BEFORE UPDATE OR DELETE ON raw_import_records" in ddl
    assert "CREATE TABLE raw_import_record_corrections" in ddl
    assert (
        "FOREIGN KEY (organization_id, raw_record_id, supersedes_correction_id)" in ddl
    )
    assert "BEFORE UPDATE OR DELETE ON raw_import_record_corrections" in ddl
