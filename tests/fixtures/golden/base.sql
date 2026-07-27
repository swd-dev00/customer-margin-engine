INSERT INTO organizations (id, name, slug)
VALUES
  (100, 'Golden North', 'golden-north'),
  (200, 'Golden South', 'golden-south');

INSERT INTO customers (id, organization_id, external_id, name)
VALUES
  (1001, 100, 'customer-a', 'Customer A'),
  (1002, 100, 'customer-b', 'Customer B'),
  (2001, 200, 'customer-a', 'Customer A South');

INSERT INTO projects (id, organization_id, customer_id, external_id, name)
VALUES
  (1011, 100, 1001, 'project-a', 'Project A'),
  (2011, 200, 2001, 'project-a', 'Project A South');

INSERT INTO import_sources (
  id,
  organization_id,
  vendor_name,
  display_name,
  source_type
)
VALUES
  (1101, 100, 'generic-billing', 'Golden Billing', 'revenue'),
  (1102, 100, 'generic-costs', 'Golden Costs', 'cost'),
  (2101, 200, 'generic-billing', 'Golden Billing South', 'revenue');

INSERT INTO import_batches (
  id,
  organization_id,
  import_source_id,
  batch_id,
  status,
  record_count,
  imported_at
)
VALUES
  (1201, 100, 1101, '2026-01-revenue', 'completed', 3, now()),
  (1202, 100, 1102, '2026-01-cost', 'completed', 2, now()),
  (2201, 200, 2101, '2026-01-revenue', 'completed', 1, now());

INSERT INTO raw_import_records (
  id,
  organization_id,
  import_batch_id,
  raw_data,
  source_id
)
VALUES
  (1301, 100, 1201, '{"kind":"invoice","amount":"100.00"}', 'invoice-001'),
  (1302, 100, 1201, '{"kind":"reversal","amount":"-10.00"}', 'credit-001'),
  (1303, 100, 1201, '{"kind":"invoice","customer":"unknown"}', 'invoice-unmapped'),
  (1311, 100, 1202, '{"kind":"ai_usage","amount":"30.00"}', 'cost-ai-shared'),
  (1312, 100, 1202, '{"kind":"support","amount":"12.00"}', 'cost-support-direct'),
  (2301, 200, 2201, '{"kind":"invoice","amount":"25.00"}', 'invoice-001');

INSERT INTO config_versions (
  id,
  organization_id,
  config_type,
  version_number,
  content,
  fingerprint,
  status,
  effective_from,
  approved_by,
  approved_at
)
VALUES
  (1401, 100, 'revenue_mapping', 1, '{"source":"generic"}', 'map-v1', 'approved', '2026-01-01', 'fixture', now()),
  (1402, 100, 'cost_classification', 1, '{"source":"generic"}', 'class-v1', 'approved', '2026-01-01', 'fixture', now()),
  (1403, 100, 'driver_definitions', 1, '{"source":"generic"}', 'driver-v1', 'approved', '2026-01-01', 'fixture', now()),
  (1404, 100, 'allocation_rules', 1, '{"source":"generic"}', 'rules-v1', 'approved', '2026-01-01', 'fixture', now()),
  (2401, 200, 'revenue_mapping', 1, '{"source":"generic"}', 'south-map-v1', 'approved', '2026-01-01', 'fixture', now());

INSERT INTO mapping_rules (
  id,
  organization_id,
  config_version_id,
  source_type,
  source_vendor,
  match_priority,
  match_field,
  customer_field,
  project_field,
  amount_field,
  currency_field,
  period_start_field,
  period_end_field
)
VALUES
  (1501, 100, 1401, 'invoice', 'generic-billing', 10, 'external_id', 'customer_id', 'project_id', 'amount', 'currency', 'period_start', 'period_end'),
  (1502, 100, 1401, 'cost', 'generic-costs', 10, 'external_id', 'customer_id', 'project_id', 'amount', 'currency', 'period_start', 'period_end'),
  (2501, 200, 2401, 'invoice', 'generic-billing', 10, 'external_id', 'customer_id', 'project_id', 'amount', 'currency', 'period_start', 'period_end');
