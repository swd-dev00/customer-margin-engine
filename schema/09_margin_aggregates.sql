-- ============================================================================
-- Slice 10: Fully Allocated Margin Aggregation
-- ============================================================================

-- Fully allocated margin aggregates (per customer/project/period/currency)
CREATE TABLE fully_allocated_margin_aggregates (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  calculation_run_id BIGINT NOT NULL REFERENCES calculation_runs(id) ON DELETE CASCADE,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  project_id BIGINT REFERENCES projects(id) ON DELETE SET NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  currency TEXT NOT NULL,
  revenue_amount NUMERIC NOT NULL,
  direct_variable_cost NUMERIC NOT NULL DEFAULT 0,
  direct_fixed_cost NUMERIC NOT NULL DEFAULT 0,
  allocated_shared_cogs NUMERIC NOT NULL DEFAULT 0,
  unallocated_cost NUMERIC NOT NULL DEFAULT 0,
  contribution_margin_dollars NUMERIC NOT NULL,
  contribution_margin_pct NUMERIC,
  fully_allocated_gross_margin_dollars NUMERIC NOT NULL,
  fully_allocated_gross_margin_pct NUMERIC,
  attribution_coverage_pct NUMERIC,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, calculation_run_id, customer_id, project_id, period_start, period_end, currency)
);

CREATE INDEX idx_fully_allocated_margin_org ON fully_allocated_margin_aggregates(organization_id);
CREATE INDEX idx_fully_allocated_margin_run ON fully_allocated_margin_aggregates(calculation_run_id);
CREATE INDEX idx_fully_allocated_margin_customer ON fully_allocated_margin_aggregates(customer_id);
CREATE INDEX idx_fully_allocated_margin_project ON fully_allocated_margin_aggregates(project_id);
CREATE INDEX idx_fully_allocated_margin_period ON fully_allocated_margin_aggregates(period_start, period_end);
