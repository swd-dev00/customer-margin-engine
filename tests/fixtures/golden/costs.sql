INSERT INTO cost_events (
  id,
  organization_id,
  raw_record_id,
  import_batch_id,
  source_vendor,
  source_id,
  source_period_start,
  source_period_end,
  source_amount,
  source_currency,
  source_lineage
)
VALUES
  (1801, 100, 1311, 1202, 'generic-costs', 'cost-ai-shared', '2026-01-01', '2026-01-31', 30.00, 'USD', '{"fixture":"shared-ai"}'),
  (1802, 100, 1312, 1202, 'generic-costs', 'cost-support-direct', '2026-01-01', '2026-01-31', 12.00, 'USD', '{"fixture":"direct-support"}');

INSERT INTO mapped_costs (
  id,
  organization_id,
  cost_event_id,
  mapping_rule_id,
  customer_id,
  project_id,
  period_start,
  period_end,
  amount,
  currency,
  cost_type
)
VALUES
  (1901, 100, 1801, 1502, NULL, NULL, '2026-01-01', '2026-01-31', 30.00, 'USD', 'shared'),
  (1902, 100, 1802, 1502, 1001, 1011, '2026-01-01', '2026-01-31', 12.00, 'USD', 'direct');

INSERT INTO cost_classifications (
  id,
  organization_id,
  config_version_id,
  classification_code,
  name,
  cost_category,
  cost_behavior,
  match_priority,
  effective_from
)
VALUES
  (2001, 100, 1402, 'AI_SHARED', 'Shared AI usage', 'ai_usage', 'shared', 10, '2026-01-01'),
  (2002, 100, 1402, 'SUPPORT_DIRECT', 'Direct support', 'support', 'variable', 20, '2026-01-01');

INSERT INTO classified_costs (
  id,
  organization_id,
  mapped_cost_id,
  classification_id,
  classification_code,
  cost_category,
  cost_behavior,
  amount,
  currency
)
VALUES
  (2101, 100, 1901, 2001, 'AI_SHARED', 'ai_usage', 'shared', 30.00, 'USD'),
  (2102, 100, 1902, 2002, 'SUPPORT_DIRECT', 'support', 'direct_variable', 12.00, 'USD');
