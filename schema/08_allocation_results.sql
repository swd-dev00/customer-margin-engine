-- ============================================================================
-- Slice 9: Shared Cost Allocation Results with Deterministic Residuals
-- ============================================================================

-- Allocation rows (one per customer/project per shared cost with rule evidence)
CREATE TABLE allocation_rows (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  calculation_run_id BIGINT NOT NULL REFERENCES calculation_runs(id) ON DELETE CASCADE,
  source_cost_id BIGINT NOT NULL REFERENCES classified_costs(id),
  target_customer_id BIGINT NOT NULL REFERENCES customers(id),
  target_project_id BIGINT REFERENCES projects(id),
  allocation_rule_id BIGINT NOT NULL REFERENCES allocation_rules(id),
  driver_definition_id BIGINT NOT NULL REFERENCES driver_definitions(id),
  numerator NUMERIC NOT NULL,
  denominator NUMERIC NOT NULL,
  ratio NUMERIC NOT NULL,
  pre_round_value NUMERIC NOT NULL,
  allocated_amount NUMERIC NOT NULL,
  residual_delta NUMERIC NOT NULL,
  rule_version INT NOT NULL,
  driver_confidence TEXT NOT NULL,
  source_lineage JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_allocation_rows_run ON allocation_rows(calculation_run_id);
CREATE INDEX idx_allocation_rows_source_cost ON allocation_rows(source_cost_id);
CREATE INDEX idx_allocation_rows_customer ON allocation_rows(target_customer_id);
CREATE INDEX idx_allocation_rows_project ON allocation_rows(target_project_id);
CREATE INDEX idx_allocation_rows_rule ON allocation_rows(allocation_rule_id);

-- Unallocated costs (explicit rows when no valid denominator exists)
CREATE TABLE unallocated_costs (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  calculation_run_id BIGINT NOT NULL REFERENCES calculation_runs(id) ON DELETE CASCADE,
  source_cost_id BIGINT NOT NULL REFERENCES classified_costs(id),
  reason TEXT NOT NULL CHECK (reason IN ('zero_denominator', 'missing_driver', 'ineligible_cost', 'negative_credit', 'no_fallback')),
  unallocated_amount NUMERIC NOT NULL,
  rule_attempt JSONB,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_unallocated_costs_run ON unallocated_costs(calculation_run_id);
CREATE INDEX idx_unallocated_costs_reason ON unallocated_costs(reason);
