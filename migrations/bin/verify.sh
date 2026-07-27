#!/bin/bash
# Verification and consistency checks

set -euo pipefail

ENV=${ENV:-dev}

echo "[verify.sh] Running verification for env=$ENV"

# Get database URL
if [ "$ENV" = "prod" ]; then
  DB_URL="${PROD_DATABASE_URL:-}"
elif [ "$ENV" = "staging" ]; then
  DB_URL="${STAGING_DATABASE_URL:-}"
else
  DB_URL="${DEV_DATABASE_URL:-}"
fi

if [ -z "$DB_URL" ]; then
  echo "[ERROR] Database URL not set for env=$ENV"
  exit 1
fi

# Verify schema fingerprints
echo "[verify.sh] Checking config fingerprints..."
psql "$DB_URL" << 'EOF'
SELECT 
  config_type, version_number, fingerprint, status, effective_from
FROM config_versions
ORDER BY config_type, version_number DESC;
EOF

# Check for orphaned records
echo "[verify.sh] Checking for orphaned records..."
psql "$DB_URL" << 'EOF'
SELECT COUNT(*) as orphaned_revenue_events
FROM revenue_events
WHERE raw_record_id NOT IN (SELECT id FROM raw_import_records);

SELECT COUNT(*) as orphaned_cost_events
FROM cost_events
WHERE raw_record_id NOT IN (SELECT id FROM raw_import_records);
EOF

# Check locked periods
echo "[verify.sh] Checking locked periods..."
psql "$DB_URL" << 'EOF'
SELECT 
  period_start, period_end, status, locked_at, locked_by
FROM period_locks
WHERE status = 'locked'
ORDER BY locked_at DESC
LIMIT 10;
EOF

# Check for pending calculations on locked periods
echo "[verify.sh] Checking for pending calculations on locked periods..."
psql "$DB_URL" << 'EOF'
SELECT COUNT(*) as pending_runs_on_locked_periods
FROM calculation_runs r
JOIN period_locks pl ON 
  r.period_start = pl.period_start 
  AND r.period_end = pl.period_end
  AND r.organization_id = pl.organization_id
WHERE r.status IN ('queued', 'running')
  AND pl.status = 'locked';
EOF

echo "[verify.sh] Verification complete."
