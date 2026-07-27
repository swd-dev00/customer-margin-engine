#!/bin/bash
# migration runner with advisory lock support

set -euo pipefail

ENV=${ENV:-dev}
TO_VERSION=${TO_VERSION:-}
LOCK_TIMEOUT=${LOCK_TIMEOUT:-0}
DRY_RUN=${DRY_RUN:-false}

echo "[migrate.sh] Starting migration for env=$ENV to_version=$TO_VERSION lock_timeout=$LOCK_TIMEOUT"

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

# Function: acquire advisory lock
acquire_lock() {
  local lock_id=1
  local timeout=$1
  
  if [ "$timeout" -eq 0 ]; then
    echo "[migrate.sh] Skipping advisory lock (timeout=0)"
    return 0
  fi
  
  echo "[migrate.sh] Acquiring advisory lock (timeout=${timeout}s)..."
  psql "$DB_URL" -c "SET statement_timeout TO ${timeout}000; SELECT pg_advisory_lock($lock_id);"
  echo "[migrate.sh] Lock acquired."
}

# Function: release advisory lock
release_lock() {
  local lock_id=1
  echo "[migrate.sh] Releasing advisory lock..."
  psql "$DB_URL" -c "SELECT pg_advisory_unlock($lock_id);" || true
}

# Cleanup on exit
trap release_lock EXIT

# Acquire lock if specified
if [ "$LOCK_TIMEOUT" -gt 0 ]; then
  acquire_lock "$LOCK_TIMEOUT"
fi

# Pre-flight checks
echo "[migrate.sh] Running pre-flight checks..."
psql "$DB_URL" << 'EOF'
BEGIN;
SELECT 1 FROM organizations LIMIT 1;
SELECT 1 FROM config_versions LIMIT 1;
COMMIT;
EOF

# Deploy migrations
echo "[migrate.sh] Deploying migrations..."
for migration_file in migrations/sql/000*.sql; do
  filename=$(basename "$migration_file")
  version=$(echo "$filename" | cut -d- -f1)
  
  if [ -n "$TO_VERSION" ] && [ "$version" -gt "$TO_VERSION" ]; then
    echo "[migrate.sh] Skipping $filename (version $version > target $TO_VERSION)"
    continue
  fi
  
  echo "[migrate.sh] Applying $filename..."
  if [ "$DRY_RUN" = "true" ]; then
    echo "[DRY_RUN] Would apply: $filename"
  else
    psql "$DB_URL" -f "$migration_file" || {
      echo "[ERROR] Migration failed: $filename"
      exit 1
    }
  fi
done

echo "[migrate.sh] Migration complete."
