#!/bin/bash
# Rollback runner (forward-only deployments are safest)

set -euo pipefail

FROM_VERSION=${FROM_VERSION:-}
TO_VERSION=${TO_VERSION:-}
ENV=${ENV:-dev}

echo "[rollback.sh] WARNING: Rollback is a destructive operation."
echo "[rollback.sh] Rolling back env=$ENV from $FROM_VERSION to $TO_VERSION"
echo "[rollback.sh] Have you tested this rollback in a staging environment? (yes/no)"
read -r CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "[rollback.sh] Rollback cancelled."
  exit 1
fi

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

echo "[rollback.sh] Executing rollback..."
psql "$DB_URL" << EOF
-- Rollback migration from $FROM_VERSION to $TO_VERSION
-- This is a forward-only migration; data may be lost.
BEGIN;
-- Add rollback SQL here
COMMIT;
EOF

echo "[rollback.sh] Rollback complete."
