-- ============================================================================
-- Slice 13: Audit, Exception, & Query Contracts
-- ============================================================================

-- Query audit log (for compliance and debugging)
CREATE TABLE query_audits (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  actor_id TEXT NOT NULL,
  query_type TEXT NOT NULL CHECK (query_type IN ('margin_snapshot', 'cost_breakdown', 'drill_down', 'exception_list', 'calculation_run', 'reconciliation')),
  snapshot_id BIGINT REFERENCES margin_snapshots(id),
  calculation_run_id BIGINT REFERENCES calculation_runs(id),
  filters JSONB,
  result_count INT,
  executed_at TIMESTAMP NOT NULL DEFAULT now(),
  response_time_ms INT
);

CREATE INDEX idx_query_audits_org ON query_audits(organization_id);
CREATE INDEX idx_query_audits_actor ON query_audits(actor_id);
CREATE INDEX idx_query_audits_type ON query_audits(query_type);
CREATE INDEX idx_query_audits_executed_at ON query_audits(executed_at);

-- Exception resolution log (tracks resolution history)
CREATE TABLE exception_resolutions (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  exception_id BIGINT NOT NULL,
  exception_type TEXT NOT NULL CHECK (exception_type IN ('revenue', 'mapping', 'classification', 'reconciliation')),
  original_reason TEXT NOT NULL,
  resolution_action TEXT NOT NULL,
  resolution_actor TEXT NOT NULL,
  resolved_at TIMESTAMP NOT NULL DEFAULT now(),
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_exception_resolutions_org ON exception_resolutions(organization_id);
CREATE INDEX idx_exception_resolutions_type ON exception_resolutions(exception_type);
CREATE INDEX idx_exception_resolutions_resolved_at ON exception_resolutions(resolved_at);
