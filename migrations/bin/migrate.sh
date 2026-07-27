#!/usr/bin/env bash

set -euo pipefail

target_environment=${TARGET_ENVIRONMENT:-dev}
to_version=${TO_VERSION:-}
lock_timeout=${LOCK_TIMEOUT:-30}
dry_run=${DRY_RUN:-false}
script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd -- "$script_directory/../.." && pwd)

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

if [[ -n "$to_version" && ! "$to_version" =~ ^[0-9]{1,2}$ ]]; then
  echo "[ERROR] TO_VERSION must contain one or two digits" >&2
  exit 2
fi

if [[ ! "$lock_timeout" =~ ^[0-9]+$ ]]; then
  echo "[ERROR] LOCK_TIMEOUT must be a non-negative integer" >&2
  exit 2
fi

mapfile -t schema_files < <(
  find "$repository_root/schema" -maxdepth 1 -type f \
    -name '[0-9][0-9]_*.sql' -print | sort
)

selected_files=()
for schema_file in "${schema_files[@]}"; do
  filename=$(basename -- "$schema_file")
  file_version=${filename%%_*}
  if [[ -n "$to_version" ]] && \
    ((10#$file_version > 10#$to_version)); then
    continue
  fi
  selected_files+=("$schema_file")
done

if ((${#selected_files[@]} == 0)); then
  echo "[ERROR] no schema files selected" >&2
  exit 1
fi

echo "[migrate] environment=$target_environment files=${#selected_files[@]}"
printf '[migrate] %s\n' "${selected_files[@]#"$repository_root/"}"

if [[ "$dry_run" == "true" ]]; then
  exit 0
fi

if [[ -z "$database_url" ]]; then
  echo "[ERROR] database URL is not set for $target_environment" >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "[ERROR] psql is required" >&2
  exit 1
fi

sql_file=$(mktemp)
cleanup() {
  rm -f -- "$sql_file"
}
trap cleanup EXIT

{
  printf "SET lock_timeout TO '%ss';\n" "$lock_timeout"
  printf 'SELECT pg_advisory_xact_lock(638491201);\n'
  for schema_file in "${selected_files[@]}"; do
    escaped_file=${schema_file//\'/\'\'}
    printf "\\ir '%s'\n" "$escaped_file"
  done
} >"$sql_file"

psql -X \
  --set ON_ERROR_STOP=1 \
  --single-transaction \
  --dbname "$database_url" \
  --file "$sql_file"

echo "[migrate] schema bootstrap complete"
