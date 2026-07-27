-- ============================================================================
-- Slice 8: Calculation Run Orchestration & Concurrency Control
-- ============================================================================

-- Calculation runs (one per organization/period/rule-set combination)
CREATE TABLE calculation_runs (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  rule_set_id BIGINT NOT NULL REFERENCES allocation_rule_sets(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'running', 'completed', 'failed', 'published')),
  revision INT NOT NULL DEFAULT 1,
  input_hash TEXT NOT NULL,
  config_hash TEXT NOT NULL,
  rule_hash TEXT NOT NULL,
  code_version TEXT NOT NULL,
  total_revenue NUMERIC,
  total_direct_variable_cost NUMERIC,
  total_direct_fixed_cost NUMERIC,
  total_shared_allocated NUMERIC,
  total_unallocated NUMERIC,
  error_message TEXT,
  started_at TIMESTAMP,
  completed_at TIMESTAMP,
  published_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, period_start, period_end, rule_set_id, status) WHERE status IN ('queued', 'running')
);

CREATE INDEX idx_calculation_runs_org ON calculation_runs(organization_id);
CREATE INDEX idx_calculation_runs_status ON calculation_runs(status);
CREATE INDEX idx_calculation_runs_period ON calculation_runs(period_start, period_end);
CREATE INDEX idx_calculation_runs_rule_set ON calculation_runs(rule_set_id);

-- Calculation run revisions (history for corrections)
CREATE TABLE calculation_run_revisions (
  id BIGSERIAL PRIMARY KEY,
  calculation_run_id BIGINT NOT NULL REFERENCES calculation_runs(id) ON DELETE CASCADE,
  revision INT NOT NULL,
  reason TEXT,
  created_by TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_calc_run_revisions_run ON calculation_run_revisions(calculation_run_id);
