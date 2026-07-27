INSERT INTO revenue_events (
  id,
  organization_id,
  raw_record_id,
  import_batch_id,
  source_type,
  source_id,
  source_period_start,
  source_period_end,
  source_amount,
  source_currency,
  source_lineage
)
VALUES
  (1601, 100, 1301, 1201, 'invoice', 'invoice-001', '2026-01-01', '2026-01-31', 100.00, 'USD', '{"fixture":"invoice"}'),
  (1602, 100, 1302, 1201, 'invoice', 'credit-001', '2026-01-01', '2026-01-31', -10.00, 'USD', '{"fixture":"reversal","reverses":"invoice-001"}'),
  (1603, 100, 1303, 1201, 'invoice', 'invoice-unmapped', '2026-01-01', '2026-01-31', 9.00, 'USD', '{"fixture":"unmapped"}'),
  (2601, 200, 2301, 2201, 'invoice', 'invoice-001', '2026-01-01', '2026-01-31', 25.00, 'USD', '{"fixture":"cross-tenant"}');

INSERT INTO normalized_revenue (
  id,
  organization_id,
  revenue_event_id,
  customer_id,
  project_id,
  period_start,
  period_end,
  amount,
  currency,
  status
)
VALUES
  (1701, 100, 1601, 1001, 1011, '2026-01-01', '2026-01-31', 100.00, 'USD', 'mapped'),
  (1702, 100, 1602, 1001, 1011, '2026-01-01', '2026-01-31', -10.00, 'USD', 'mapped'),
  (2701, 200, 2601, 2001, 2011, '2026-01-01', '2026-01-31', 25.00, 'USD', 'mapped');

INSERT INTO mapped_revenue (
  id,
  organization_id,
  revenue_event_id,
  mapping_rule_id,
  customer_id,
  project_id,
  period_start,
  period_end,
  amount,
  currency
)
VALUES
  (1751, 100, 1601, 1501, 1001, 1011, '2026-01-01', '2026-01-31', 100.00, 'USD'),
  (1752, 100, 1602, 1501, 1001, 1011, '2026-01-01', '2026-01-31', -10.00, 'USD'),
  (2751, 200, 2601, 2501, 2001, 2011, '2026-01-01', '2026-01-31', 25.00, 'USD');

INSERT INTO revenue_exceptions (
  id,
  organization_id,
  revenue_event_id,
  reason
)
VALUES
  (1791, 100, 1603, 'customer identity not found');

INSERT INTO mapping_exceptions (
  id,
  organization_id,
  source_record_id,
  source_type,
  reason
)
VALUES
  (1792, 100, 1603, 'revenue', 'customer identity not found');
