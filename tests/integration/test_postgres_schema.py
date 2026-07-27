from decimal import Decimal

import pytest

pytestmark = pytest.mark.integration


def test_all_expected_schema_slices_are_queryable(postgres_connection) -> None:
    expected_tables = {
        "allocation_rows",
        "calculation_runs",
        "classified_costs",
        "config_versions",
        "cost_events",
        "driver_values",
        "margin_snapshots",
        "organizations",
        "raw_import_records",
        "reconciliation_checks",
        "revenue_events",
        "snapshot_margin_rows",
    }
    rows = postgres_connection.execute(
        """
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = current_schema()
        """
    ).fetchall()

    assert expected_tables <= {row[0] for row in rows}


def test_source_identity_is_unique_inside_a_tenant(postgres_connection) -> None:
    from psycopg.errors import UniqueViolation

    with pytest.raises(UniqueViolation):
        postgres_connection.execute(
            """
            INSERT INTO raw_import_records (
              organization_id,
              import_batch_id,
              raw_data,
              source_id
            )
            VALUES (100, 1201, '{}'::jsonb, 'invoice-001')
            """
        )


def test_same_source_identity_is_allowed_across_tenants(
    postgres_connection,
) -> None:
    count = postgres_connection.execute(
        """
        SELECT count(*)
        FROM revenue_events
        WHERE source_id = 'invoice-001'
        """
    ).fetchone()[0]

    assert count == 2


def test_golden_reversal_remains_an_explicit_negative_event(
    postgres_connection,
) -> None:
    amount, lineage = postgres_connection.execute(
        """
        SELECT source_amount, source_lineage
        FROM revenue_events
        WHERE organization_id = 100
          AND source_id = 'credit-001'
        """
    ).fetchone()

    assert amount == Decimal("-10.00")
    assert lineage["fixture"] == "reversal"
    assert lineage["reverses"] == "invoice-001"


def test_raw_source_evidence_rejects_update_and_delete(
    postgres_connection,
) -> None:
    from psycopg.errors import ObjectNotInPrerequisiteState

    raw_hash = postgres_connection.execute(
        "SELECT raw_hash FROM raw_import_records WHERE id = 1301"
    ).fetchone()[0]

    assert len(raw_hash) == 64

    with pytest.raises(ObjectNotInPrerequisiteState):
        postgres_connection.execute(
            """
            UPDATE raw_import_records
            SET raw_data = '{"tampered":true}'::jsonb
            WHERE id = 1301
            """
        )

    with pytest.raises(ObjectNotInPrerequisiteState):
        postgres_connection.execute("DELETE FROM raw_import_records WHERE id = 1301")


def test_raw_correction_is_linked_and_append_only(postgres_connection) -> None:
    from psycopg.errors import ForeignKeyViolation, ObjectNotInPrerequisiteState

    correction_id, correction_hash = postgres_connection.execute(
        """
        INSERT INTO raw_import_record_corrections (
          organization_id,
          raw_record_id,
          raw_data,
          correction_reason,
          recorded_by
        )
        VALUES (
          100,
          1301,
          '{"kind":"invoice","amount":"101.00"}'::jsonb,
          'upstream source issued corrected evidence',
          'integration-test'
        )
        RETURNING id, raw_hash
        """
    ).fetchone()

    assert len(correction_hash) == 64

    with pytest.raises(ForeignKeyViolation):
        postgres_connection.execute(
            """
            INSERT INTO raw_import_record_corrections (
              organization_id,
              raw_record_id,
              supersedes_correction_id,
              raw_data,
              correction_reason,
              recorded_by
            )
            VALUES (
              100,
              1302,
              %s,
              '{"kind":"reversal","amount":"-9.00"}'::jsonb,
              'invalid cross-record correction chain',
              'integration-test'
            )
            """,
            (correction_id,),
        )

    with pytest.raises(ObjectNotInPrerequisiteState):
        postgres_connection.execute(
            """
            UPDATE raw_import_record_corrections
            SET correction_reason = 'tampered'
            WHERE id = %s
            """,
            (correction_id,),
        )

    with pytest.raises(ObjectNotInPrerequisiteState):
        postgres_connection.execute(
            "DELETE FROM raw_import_record_corrections WHERE id = %s",
            (correction_id,),
        )


def test_shared_allocation_conserves_the_classified_cost(
    postgres_connection,
) -> None:
    source_amount, allocated_amount, unallocated_amount = postgres_connection.execute(
        """
            SELECT
              source.amount,
              coalesce(sum(allocation.allocated_amount), 0),
              coalesce((
                SELECT sum(unallocated.unallocated_amount)
                FROM unallocated_costs AS unallocated
                WHERE unallocated.source_cost_id = source.id
              ), 0)
            FROM classified_costs AS source
            LEFT JOIN allocation_rows AS allocation
              ON allocation.source_cost_id = source.id
            WHERE source.id = 2101
            GROUP BY source.id, source.amount
            """
    ).fetchone()

    assert allocated_amount + unallocated_amount == source_amount
    assert source_amount == Decimal("30.00")


def test_published_fixture_has_a_balanced_final_reconciliation(
    postgres_connection,
) -> None:
    result = postgres_connection.execute(
        """
        SELECT
          reconciliation.is_balanced,
          reconciliation.difference
        FROM margin_snapshots AS snapshot
        JOIN reconciliation_checks AS reconciliation
          ON reconciliation.calculation_run_id = snapshot.calculation_run_id
        WHERE snapshot.id = 3001
          AND snapshot.status = 'published'
          AND reconciliation.stage = 'final_reconciliation'
        """
    ).fetchone()

    assert result == (True, Decimal("0.00"))
