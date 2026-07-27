INSERT INTO driver_definitions (
  id,
  organization_id,
  config_version_id,
  driver_code,
  name,
  unit,
  effective_from
)
VALUES
  (2201, 100, 1403, 'WEIGHTED_TOKENS', 'Weighted AI tokens', 'token', '2026-01-01');

INSERT INTO driver_values (
  id,
  organization_id,
  driver_definition_id,
  customer_id,
  period_start,
  period_end,
  value,
  source_lineage
)
VALUES
  (2301, 100, 2201, 1001, '2026-01-01', '2026-01-31', 2, '{"fixture":"driver-a"}'),
  (2302, 100, 2201, 1002, '2026-01-01', '2026-01-31', 1, '{"fixture":"driver-b"}');

INSERT INTO driver_aggregates (
  id,
  organization_id,
  driver_definition_id,
  period_start,
  period_end,
  total_value,
  non_missing_count
)
VALUES
  (2351, 100, 2201, '2026-01-01', '2026-01-31', 3, 2);

INSERT INTO allocation_rule_sets (
  id,
  organization_id,
  config_version_id,
  version_number,
  name,
  approval_state,
  fingerprint,
  approved_by,
  approved_at
)
VALUES
  (2401, 100, 1404, 1, 'Golden allocation rules', 'approved', 'rules-v1', 'fixture', now());

INSERT INTO allocation_rules (
  id,
  organization_id,
  rule_set_id,
  priority,
  cost_category,
  driver_definition_id,
  description
)
VALUES
  (2501, 100, 2401, 10, 'ai_usage', 2201, 'Allocate shared AI by weighted tokens');

INSERT INTO calculation_runs (
  id,
  organization_id,
  rule_set_id,
  period_start,
  period_end,
  status,
  revision,
  input_hash,
  config_hash,
  rule_hash,
  code_version,
  total_revenue,
  total_direct_variable_cost,
  total_direct_fixed_cost,
  total_shared_allocated,
  total_unallocated,
  started_at,
  completed_at,
  published_at
)
VALUES
  (2601, 100, 2401, '2026-01-01', '2026-01-31', 'published', 1, 'input-v1', 'config-v1', 'rules-v1', 'fixture-v1', 90.00, 12.00, 0.00, 30.00, 0.00, now(), now(), now());

INSERT INTO allocation_rows (
  id,
  organization_id,
  calculation_run_id,
  source_cost_id,
  target_customer_id,
  allocation_rule_id,
  driver_definition_id,
  numerator,
  denominator,
  ratio,
  pre_round_value,
  allocated_amount,
  residual_delta,
  rule_version,
  driver_confidence,
  source_lineage
)
VALUES
  (2701, 100, 2601, 2101, 1001, 2501, 2201, 2, 3, 0.6666666667, 20.00, 20.00, 0.00, 1, 'high', '{"fixture":"allocation-a"}'),
  (2702, 100, 2601, 2101, 1002, 2501, 2201, 1, 3, 0.3333333333, 10.00, 10.00, 0.00, 1, 'high', '{"fixture":"allocation-b"}');

INSERT INTO fully_allocated_margin_aggregates (
  id,
  organization_id,
  calculation_run_id,
  customer_id,
  project_id,
  period_start,
  period_end,
  currency,
  revenue_amount,
  direct_variable_cost,
  direct_fixed_cost,
  allocated_shared_cogs,
  unallocated_cost,
  contribution_margin_dollars,
  contribution_margin_pct,
  fully_allocated_gross_margin_dollars,
  fully_allocated_gross_margin_pct,
  attribution_coverage_pct
)
VALUES
  (2801, 100, 2601, 1001, 1011, '2026-01-01', '2026-01-31', 'USD', 90.00, 12.00, 0.00, 20.00, 0.00, 78.00, 86.6666666667, 58.00, 64.4444444444, 100.00),
  (2802, 100, 2601, 1002, NULL, '2026-01-01', '2026-01-31', 'USD', 0.00, 0.00, 0.00, 10.00, 0.00, 0.00, NULL, -10.00, NULL, 100.00);

INSERT INTO reconciliation_checks (
  id,
  organization_id,
  calculation_run_id,
  stage,
  period_start,
  period_end,
  currency,
  expected_total,
  actual_total,
  difference,
  is_balanced,
  evidence
)
VALUES
  (2901, 100, 2601, 'shared_allocation', '2026-01-01', '2026-01-31', 'USD', 30.00, 30.00, 0.00, true, '{"fixture":"allocation-conservation"}'),
  (2902, 100, 2601, 'final_reconciliation', '2026-01-01', '2026-01-31', 'USD', 42.00, 42.00, 0.00, true, '{"fixture":"publish-gate"}');

INSERT INTO reconciliation_evidences (
  id,
  organization_id,
  reconciliation_check_id,
  record_type,
  record_id,
  contribution_amount
)
VALUES
  (2951, 100, 2901, 'allocation_row', 2701, 20.00),
  (2952, 100, 2901, 'allocation_row', 2702, 10.00),
  (2953, 100, 2902, 'classified_cost', 2102, 12.00),
  (2954, 100, 2902, 'allocation_row', 2701, 20.00),
  (2955, 100, 2902, 'allocation_row', 2702, 10.00);

INSERT INTO margin_snapshots (
  id,
  organization_id,
  calculation_run_id,
  period_start,
  period_end,
  revision,
  status,
  config_fingerprint,
  rule_set_fingerprint,
  published_by,
  published_at
)
VALUES
  (3001, 100, 2601, '2026-01-01', '2026-01-31', 1, 'published', 'config-v1', 'rules-v1', 'fixture', now());

INSERT INTO snapshot_margin_rows (
  id,
  organization_id,
  snapshot_id,
  customer_id,
  project_id,
  currency,
  revenue_amount,
  direct_variable_cost,
  direct_fixed_cost,
  allocated_shared_cogs,
  unallocated_cost,
  contribution_margin_dollars,
  contribution_margin_pct,
  fully_allocated_gross_margin_dollars,
  fully_allocated_gross_margin_pct,
  attribution_coverage_pct
)
VALUES
  (3101, 100, 3001, 1001, 1011, 'USD', 90.00, 12.00, 0.00, 20.00, 0.00, 78.00, 86.6666666667, 58.00, 64.4444444444, 100.00),
  (3102, 100, 3001, 1002, NULL, 'USD', 0.00, 0.00, 0.00, 10.00, 0.00, 0.00, NULL, -10.00, NULL, 100.00);

INSERT INTO period_locks (
  id,
  organization_id,
  period_start,
  period_end,
  status,
  published_snapshot_id,
  locked_by,
  locked_at
)
VALUES
  (3201, 100, '2026-01-01', '2026-01-31', 'locked', 3001, 'fixture', now());
