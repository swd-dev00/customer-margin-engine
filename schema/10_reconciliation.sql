-- ============================================================================
-- Slice 11: Multi-Stage Reconciliation with Conservation & Audit
-- ============================================================================

-- Reconciliation checks (stage-by-stage verification)
CREATE TABLE reconciliation_checks (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  calculation_run_id BIGINT NOT NULL REFERENCES calculation_runs(id) ON DELETE CASCADE,
  stage TEXT NOT NULL CHECK (stage IN (
    'import_acceptance',
    'revenue_mapping',
    'cost_classification',
    'direct_attribution',
    'shared_allocation',
    'margin_aggregation',
    'final_reconciliation'
  )),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  currency TEXT NOT NULL,
  expected_total NUMERIC NOT NULL,
  actual_total NUMERIC NOT NULL,
  difference NUMERIC NOT NULL,
  is_balanced BOOLEAN NOT NULL,
  evidence JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_reconciliation_checks_run ON reconciliation_checks(calculation_run_id);
CREATE INDEX idx_reconciliation_checks_stage ON reconciliation_checks(stage);
CREATE INDEX idx_reconciliation_checks_balanced ON reconciliation_checks(is_balanced);

-- Reconciliation evidences (links to contributing record sets)
CREATE TABLE reconciliation_evidences (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  reconciliation_check_id BIGINT NOT NULL REFERENCES reconciliation_checks(id) ON DELETE CASCADE,
  record_type TEXT NOT NULL CHECK (record_type IN ('revenue_event', 'cost_event', 'mapped_revenue', 'mapped_cost', 'classified_cost', 'allocation_row', 'unallocated_cost', 'margin_aggregate')),
  record_id BIGINT NOT NULL,
  contribution_amount NUMERIC NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_reconciliation_evidences_check ON reconciliation_evidences(reconciliation_check_id);
