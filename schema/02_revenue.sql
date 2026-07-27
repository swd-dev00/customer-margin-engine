-- ============================================================================
-- Slice 2: Revenue Event Ingestion & Normalization
-- ============================================================================

-- Raw revenue events (one per source record)
CREATE TABLE revenue_events (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  raw_record_id BIGINT NOT NULL REFERENCES raw_import_records(id) ON DELETE CASCADE,
  import_batch_id BIGINT NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  source_type TEXT NOT NULL CHECK (source_type IN ('invoice', 'subscription', 'project')),
  source_id TEXT NOT NULL,
  source_period_start DATE NOT NULL,
  source_period_end DATE NOT NULL,
  source_amount NUMERIC NOT NULL,
  source_currency TEXT NOT NULL,
  source_lineage JSONB NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, source_id)
);

CREATE INDEX idx_revenue_events_org ON revenue_events(organization_id);
CREATE INDEX idx_revenue_events_source ON revenue_events(source_id);
CREATE INDEX idx_revenue_events_batch ON revenue_events(import_batch_id);
CREATE INDEX idx_revenue_events_period ON revenue_events(source_period_start, source_period_end);

-- Normalized revenue (one per mapped/validated revenue event)
CREATE TABLE normalized_revenue (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  revenue_event_id BIGINT NOT NULL REFERENCES revenue_events(id) ON DELETE CASCADE,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  project_id BIGINT REFERENCES projects(id) ON DELETE SET NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'mapped' CHECK (status IN ('mapped', 'unmapped', 'rejected')),
  rejection_reason TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, revenue_event_id)
);

CREATE INDEX idx_normalized_revenue_org ON normalized_revenue(organization_id);
CREATE INDEX idx_normalized_revenue_customer ON normalized_revenue(customer_id);
CREATE INDEX idx_normalized_revenue_project ON normalized_revenue(project_id);
CREATE INDEX idx_normalized_revenue_period ON normalized_revenue(period_start, period_end);
CREATE INDEX idx_normalized_revenue_status ON normalized_revenue(status);

-- Unmapped/exception queue for revenue
CREATE TABLE revenue_exceptions (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  revenue_event_id BIGINT NOT NULL REFERENCES revenue_events(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  resolution_state TEXT NOT NULL DEFAULT 'pending' CHECK (resolution_state IN ('pending', 'resolved', 'ignored')),
  resolution_action TEXT,
  resolved_by TEXT,
  resolved_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, revenue_event_id)
);

CREATE INDEX idx_revenue_exceptions_org ON revenue_exceptions(organization_id);
CREATE INDEX idx_revenue_exceptions_state ON revenue_exceptions(resolution_state);
