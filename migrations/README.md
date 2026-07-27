# PostgreSQL schema workflow

The ordered baseline DDL lives in `schema/`. The scripts in `migrations/bin/`
bootstrap a fresh database and run database-level verification.

## Baseline rules

- Files are applied in lexical order: `schema/[0-9][0-9]_*.sql`.
- Baseline DDL is for a fresh database, local tests, and CI.
- Applied production DDL is never edited retroactively.
- Production corrections require a new forward-only migration with its own
  tests and deployment record.
- Destructive rollback is intentionally unsupported. Recovery uses a tested
  forward correction or database restore procedure.

`migrations/versions.json` is a source manifest, not a record of production
deployment state. Deployment state belongs in the target database and the
release system.

## Environment selection

Set `TARGET_ENVIRONMENT` to select the connection variable:

| `TARGET_ENVIRONMENT` | Connection variable |
| --- | --- |
| `dev` (default) | `DEV_DATABASE_URL` |
| `test` | `TEST_DATABASE_URL` |
| `staging` | `STAGING_DATABASE_URL` |
| `prod` | `PROD_DATABASE_URL` |

Example:

```bash
export TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:55432/customer_margin_test
TARGET_ENVIRONMENT=test bash migrations/bin/migrate.sh
TARGET_ENVIRONMENT=test bash migrations/bin/verify.sh
```

Optional controls:

- `TO_VERSION=03` applies through `schema/03_*.sql`.
- `LOCK_TIMEOUT=30` controls advisory-lock wait time in seconds.
- `DRY_RUN=true` prints the selected files without connecting.

The bootstrap is atomic: all selected files run in one PostgreSQL transaction
under a transaction-scoped advisory lock. An error rolls back the entire
bootstrap.

## Verification

`verify.sh` fails when it finds:

- orphaned revenue or cost events;
- queued or running calculations in a locked period; or
- an unbalanced reconciliation check attached to a published calculation.

The integration suite also creates an isolated PostgreSQL schema, applies every
baseline DDL file, loads deterministic fixtures, and asserts uniqueness,
tenancy, append-only raw evidence, allocation conservation, and publication
reconciliation.

## Rollback safety

`rollback.sh` deliberately exits without changing a database. A generic
rollback cannot safely infer how to reverse financial schema or data changes.
Every production migration must document one of:

1. a forward correction;
2. a migration-specific, reviewed reversal; or
3. a database restore procedure tested against a recent backup.
