#!/usr/bin/env bash

set -euo pipefail

target_environment=${TARGET_ENVIRONMENT:-dev}

case "$target_environment" in
  dev)
    database_url=${DEV_DATABASE_URL:-}
    ;;
  test)
    database_url=${TEST_DATABASE_URL:-}
    ;;
  staging)
    database_url=${STAGING_DATABASE_URL:-}
    ;;
  prod)
    database_url=${PROD_DATABASE_URL:-}
    ;;
  *)
    echo "[ERROR] unsupported TARGET_ENVIRONMENT=$target_environment" >&2
    exit 2
    ;;
esac

if [[ -z "$database_url" ]]; then
  echo "[ERROR] database URL is not set for $target_environment" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "[ERROR] psql is required" >&2
  exit 1
fi

psql -X --set ON_ERROR_STOP=1 --dbname "$database_url" <<'SQL'
DO $verification$
BEGIN
  IF to_regclass('organizations') IS NULL THEN
    RAISE EXCEPTION 'baseline schema is not installed';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM revenue_events AS event
    LEFT JOIN raw_import_records AS raw_record
      ON raw_record.id = event.raw_record_id
    WHERE raw_record.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned revenue event detected';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM cost_events AS event
    LEFT JOIN raw_import_records AS raw_record
      ON raw_record.id = event.raw_record_id
    WHERE raw_record.id IS NULL
  ) THEN
    RAISE EXCEPTION 'orphaned cost event detected';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM calculation_runs AS run
    JOIN period_locks AS period_lock
      ON period_lock.organization_id = run.organization_id
      AND period_lock.period_start = run.period_start
      AND period_lock.period_end = run.period_end
    WHERE run.status IN ('queued', 'running')
      AND period_lock.status = 'locked'
  ) THEN
    RAISE EXCEPTION 'active calculation exists in a locked period';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM calculation_runs AS run
    JOIN reconciliation_checks AS reconciliation
      ON reconciliation.calculation_run_id = run.id
    WHERE run.status = 'published'
      AND NOT reconciliation.is_balanced
  ) THEN
    RAISE EXCEPTION 'published calculation has unbalanced reconciliation';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM margin_snapshots AS snapshot
    WHERE snapshot.status = 'published'
      AND NOT EXISTS (
        SELECT 1
        FROM snapshot_margin_rows AS snapshot_row
        WHERE snapshot_row.snapshot_id = snapshot.id
      )
  ) THEN
    RAISE EXCEPTION 'published snapshot has no margin rows';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM margin_snapshots AS snapshot
    JOIN snapshot_margin_rows AS snapshot_row
      ON snapshot_row.snapshot_id = snapshot.id
    WHERE snapshot.status = 'published'
      AND NOT EXISTS (
        SELECT 1
        FROM reconciliation_checks AS reconciliation
        WHERE reconciliation.calculation_run_id = snapshot.calculation_run_id
          AND reconciliation.stage = 'final_reconciliation'
          AND reconciliation.currency = snapshot_row.currency
          AND reconciliation.is_balanced
          AND reconciliation.difference = 0
          AND reconciliation.expected_total = reconciliation.actual_total
      )
  ) THEN
    RAISE EXCEPTION 'published snapshot is missing balanced final reconciliation';
  END IF;
END
$verification$;
SQL

echo "[verify] database invariants passed"
