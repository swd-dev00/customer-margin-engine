-- ============================================================================
-- Slice 12: Immutable Snapshot Revisions & Period Locking
-- ============================================================================

-- Margin snapshots (immutable published results per period)
CREATE TABLE margin_snapshots (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  calculation_run_id BIGINT NOT NULL REFERENCES calculation_runs(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  revision INT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'superseded')),
  config_fingerprint TEXT NOT NULL,
  rule_set_fingerprint TEXT NOT NULL,
  published_by TEXT,
  published_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, period_start, period_end, revision)
);

CREATE INDEX idx_margin_snapshots_org ON margin_snapshots(organization_id);
CREATE INDEX idx_margin_snapshots_run ON margin_snapshots(calculation_run_id);
CREATE INDEX idx_margin_snapshots_period ON margin_snapshots(period_start, period_end);
CREATE INDEX idx_margin_snapshots_status ON margin_snapshots(status);

-- Snapshot margin rows (immutable copy of fully_allocated_margin_aggregates at publication time)
CREATE TABLE snapshot_margin_rows (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  snapshot_id BIGINT NOT NULL REFERENCES margin_snapshots(id) ON DELETE CASCADE,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  project_id BIGINT REFERENCES projects(id) ON DELETE SET NULL,
  currency TEXT NOT NULL,
  revenue_amount NUMERIC NOT NULL,
  direct_variable_cost NUMERIC NOT NULL,
  direct_fixed_cost NUMERIC NOT NULL,
  allocated_shared_cogs NUMERIC NOT NULL,
  unallocated_cost NUMERIC NOT NULL,
  contribution_margin_dollars NUMERIC NOT NULL,
  contribution_margin_pct NUMERIC,
  fully_allocated_gross_margin_dollars NUMERIC NOT NULL,
  fully_allocated_gross_margin_pct NUMERIC,
  attribution_coverage_pct NUMERIC,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_snapshot_margin_rows_snapshot ON snapshot_margin_rows(snapshot_id);
CREATE INDEX idx_snapshot_margin_rows_customer ON snapshot_margin_rows(customer_id);
CREATE INDEX idx_snapshot_margin_rows_project ON snapshot_margin_rows(project_id);

-- Period locks (prevent recalculation/mutation of locked periods)
CREATE TABLE period_locks (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'locked' CHECK (status IN ('locked', 'unlocked')),
  published_snapshot_id BIGINT NOT NULL REFERENCES margin_snapshots(id),
  locked_by TEXT NOT NULL,
  locked_at TIMESTAMP NOT NULL,
  unlock_reason TEXT,
  unlocked_by TEXT,
  unlocked_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, period_start, period_end)
);

CREATE INDEX idx_period_locks_org ON period_locks(organization_id);
CREATE INDEX idx_period_locks_period ON period_locks(period_start, period_end);
CREATE INDEX idx_period_locks_status ON period_locks(status);
