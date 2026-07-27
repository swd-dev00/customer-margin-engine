-- ============================================================================
-- Slice 3: Cost Event Ingestion & Source Mapping Configuration
-- ============================================================================

-- Raw cost events (one per source record)
CREATE TABLE cost_events (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  raw_record_id BIGINT NOT NULL REFERENCES raw_import_records(id) ON DELETE CASCADE,
  import_batch_id BIGINT NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  source_vendor TEXT NOT NULL,
  source_id TEXT NOT NULL,
  source_period_start DATE NOT NULL,
  source_period_end DATE NOT NULL,
  source_amount NUMERIC NOT NULL,
  source_currency TEXT NOT NULL,
  source_lineage JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, source_id)
);

CREATE INDEX idx_cost_events_org ON cost_events(organization_id);
CREATE INDEX idx_cost_events_source ON cost_events(source_id);
CREATE INDEX idx_cost_events_batch ON cost_events(import_batch_id);
CREATE INDEX idx_cost_events_period ON cost_events(source_period_start, source_period_end);

-- Revenue/cost mapping configuration (how to find customer/project in raw data)
CREATE TABLE mapping_rules (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  config_version_id BIGINT NOT NULL REFERENCES config_versions(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL CHECK (source_type IN ('invoice', 'subscription', 'project', 'cost')),
  source_vendor TEXT,
  match_priority INT NOT NULL,
  match_field TEXT NOT NULL,
  customer_field TEXT,
  project_field TEXT,
  amount_field TEXT,
  currency_field TEXT,
  period_start_field TEXT,
  period_end_field TEXT,
  notes TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_mapping_rules_org ON mapping_rules(organization_id);
CREATE INDEX idx_mapping_rules_config ON mapping_rules(config_version_id);
CREATE INDEX idx_mapping_rules_priority ON mapping_rules(organization_id, source_type, match_priority);

-- Mapped revenue (matches revenue event to customer/project)
CREATE TABLE mapped_revenue (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  revenue_event_id BIGINT NOT NULL REFERENCES revenue_events(id) ON DELETE CASCADE,
  mapping_rule_id BIGINT NOT NULL REFERENCES mapping_rules(id),
  customer_id BIGINT NOT NULL REFERENCES customers(id),
  project_id BIGINT REFERENCES projects(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'mapped' CHECK (status IN ('mapped', 'unmapped')),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, revenue_event_id)
);

CREATE INDEX idx_mapped_revenue_org ON mapped_revenue(organization_id);
CREATE INDEX idx_mapped_revenue_customer ON mapped_revenue(customer_id);
CREATE INDEX idx_mapped_revenue_project ON mapped_revenue(project_id);
CREATE INDEX idx_mapped_revenue_period ON mapped_revenue(period_start, period_end);

-- Mapped costs (matches cost event to customer/project or marks as shared)
CREATE TABLE mapped_costs (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  cost_event_id BIGINT NOT NULL REFERENCES cost_events(id) ON DELETE CASCADE,
  mapping_rule_id BIGINT REFERENCES mapping_rules(id),
  customer_id BIGINT REFERENCES customers(id),
  project_id BIGINT REFERENCES projects(id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL,
  cost_type TEXT NOT NULL CHECK (cost_type IN ('direct', 'shared', 'unallocated')),
  status TEXT NOT NULL DEFAULT 'mapped' CHECK (status IN ('mapped', 'unmapped')),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, cost_event_id)
);

CREATE INDEX idx_mapped_costs_org ON mapped_costs(organization_id);
CREATE INDEX idx_mapped_costs_customer ON mapped_costs(customer_id);
CREATE INDEX idx_mapped_costs_project ON mapped_costs(project_id);
CREATE INDEX idx_mapped_costs_type ON mapped_costs(cost_type);
CREATE INDEX idx_mapped_costs_period ON mapped_costs(period_start, period_end);

-- Mapping exceptions (unmapped records queued for resolution)
CREATE TABLE mapping_exceptions (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  source_record_id BIGINT NOT NULL,
  source_type TEXT NOT NULL CHECK (source_type IN ('revenue', 'cost')),
  reason TEXT NOT NULL,
  resolution_state TEXT NOT NULL DEFAULT 'pending' CHECK (resolution_state IN ('pending', 'resolved', 'ignored')),
  resolution_action TEXT,
  resolved_by TEXT,
  resolved_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_mapping_exceptions_org ON mapping_exceptions(organization_id);
CREATE INDEX idx_mapping_exceptions_state ON mapping_exceptions(resolution_state);
