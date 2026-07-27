# Customer Margin Engine

A configuration-driven PostgreSQL backend for auditable customer cost
attribution, contribution margin, and fully allocated gross margin.

## Repository status

This repository currently contains the canonical PostgreSQL schema, migration
bootstrap tooling, and verification scaffolding. Source adapters, application
services, and HTTP query handlers will be implemented in later slices against
the contracts documented here.

## Deployable v1 contract

Deployable v1 will:

- ingest source-agnostic revenue, cost, usage, labor, and operational records;
- retain organization-scoped raw source evidence and source lineage;
- normalize revenue and costs into one canonical ledger;
- apply effective-dated, versioned mapping, classification, driver, and
  allocation configuration;
- calculate contribution margin and fully allocated gross margin by customer,
  project, accounting period, and currency;
- preserve direct assignments, allocation numerators and denominators,
  deterministic residuals, and rule versions;
- reconcile source, mapped, classified, allocated, and published totals;
- expose explicit exception queues instead of silently discarding records; and
- publish immutable snapshot revisions and lock closed periods.

Money is stored as PostgreSQL `NUMERIC`. Every monetary record carries an ISO
4217 currency code, and calculations and reconciliations are performed per
currency. `organization_id` is the tenancy boundary throughout the canonical
model.

### Margin definitions

```text
Contribution margin
  = revenue - direct variable service cost

Fully allocated gross margin
  = revenue
    - direct variable service cost
    - direct fixed service cost
    - allocated shared cost of service

Gross margin %
  = gross margin / revenue * 100
```

Percentage values are nullable when revenue is zero. Fully allocated gross
margin is a management profitability metric and may differ from formal
financial-reporting presentation.

## Architecture

```text
source adapters
    |
    v
raw imports and exception queues
    |
    v
canonical revenue and cost ledger
    |
    v
versioned mapping and classification
    |
    v
drivers and deterministic allocations
    |
    v
reconciliation and margin aggregation
    |
    v
immutable snapshots and query audit
```

The database owns normalized financial truth. Vendor-specific payload fields
remain in JSON source evidence or adapter configuration rather than becoming
canonical columns.

### Schema slices

| Files | Responsibility |
| --- | --- |
| `01_foundation.sql` | Organizations, customers, projects, imports, and configuration versions |
| `02_revenue.sql` | Revenue events, normalization, and revenue exceptions |
| `03_cost_mapping.sql` | Cost events, source mappings, and mapping exceptions |
| `04_cost_classification.sql` | Cost classification and contribution margin |
| `05_allocation_drivers.sql` | Driver definitions, observations, and aggregates |
| `06_allocation_rules.sql` | Versioned allocation rule sets |
| `07_calculation_runs.sql` | Calculation orchestration and concurrency boundary |
| `08_allocation_results.sql` | Allocation evidence, residuals, and unallocated costs |
| `09_margin_aggregates.sql` | Fully allocated customer/project margins |
| `10_reconciliation.sql` | Stage-level reconciliation and evidence |
| `11_snapshots.sql` | Snapshot revisions and period locks |
| `12_audit_queries.sql` | Query audit and exception-resolution history |
| `13_raw_evidence_immutability.sql` | Append-only raw evidence and explicit corrections |

## Financial and audit invariants

- Source uniqueness is scoped to an organization and stable source identity.
- Corrections are represented by new financial events or revisions; published
  evidence is never silently replaced.
- Raw import records and their correction ledger reject database `UPDATE` and
  `DELETE`; corrections are linked append-only rows with operator and reason.
- Approved configuration and rule versions remain attributable to the
  calculation runs that used them.
- Shared cost allocation must conserve the original source amount:
  `allocated + unallocated = source cost`.
- Rounding residuals use a documented deterministic ordering.
- A published snapshot requires balanced reconciliation evidence.
- Concurrent active calculation runs are restricted per organization, period,
  and rule set.
- Cross-tenant identifiers never grant cross-tenant access.

## Repository layout

```text
.github/workflows/   continuous integration
migrations/bin/      schema bootstrap and verification commands
schema/              ordered PostgreSQL DDL slices
tests/contract/      repository and static schema contracts
tests/property/      deterministic financial invariant oracles
tests/integration/   PostgreSQL behavior checks
tests/fixtures/      deterministic golden records
```

## Local development

Prerequisites:

- Python 3.12+
- Docker with Compose v2
- GNU Make (optional; every command is also shown directly)

Create an environment and install development dependencies:

```bash
python -m venv .venv
python -m pip install -r requirements-dev.txt
```

Start the disposable PostgreSQL test database:

```bash
docker compose -f compose.test.yml up -d --wait
```

Copy `.env.test.example` to `.env.test`, or export its
`TEST_DATABASE_URL` value in your shell. Then run:

```bash
python -m ruff check .
python -m ruff format --check .
python -m pytest -m "not integration"
python -m pytest -m integration
```

The equivalent Make targets are `make lint`, `make test`,
`make test-integration`, and `make verify`.

Stop the disposable database without deleting unrelated Docker resources:

```bash
docker compose -f compose.test.yml down --volumes
```

## Schema bootstrap

The committed DDL files are applied in lexical order to a fresh database:

```bash
export TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:55432/customer_margin_test
TARGET_ENVIRONMENT=test bash migrations/bin/migrate.sh
TARGET_ENVIRONMENT=test bash migrations/bin/verify.sh
```

`migrate.sh` runs the selected DDL files in one transaction while holding a
PostgreSQL transaction-scoped advisory lock. Set `TO_VERSION=03` to stop after
the first three slices. This is a fresh-database bootstrap; deployed databases
must use reviewed forward-only migrations rather than replaying baseline DDL.
See `migrations/README.md`.

## Verification

CI runs:

1. Ruff lint and format checks for Python test/support code.
2. ShellCheck for migration scripts.
3. Contract and property tests without external services.
4. PostgreSQL 16 integration tests that apply all ordered DDL and golden
   fixtures in an isolated schema.
5. Duplicate-boundary, cross-tenant, allocation-conservation, reconciliation,
   and snapshot-publication assertions.

Local integration tests skip with an explicit reason when
`TEST_DATABASE_URL` is not set. CI always provides it.

## Change policy

- Do not amend or reorder a deployed schema slice.
- Use a new forward-only migration for corrections to deployed databases.
- Keep migration and configuration changes effective-dated and auditable.
- Run reconciliation checks before publishing or locking a period.
- Never place credentials, production payloads, or customer data in fixtures.

## Explicit exclusions

The v1 engine does **not** include:

- forecasting;
- pricing optimization;
- customer lifetime value analysis;
- churn prediction; or
- automated contract repricing.

Those capabilities may consume published margin snapshots in later products,
but they are not part of this engine.
