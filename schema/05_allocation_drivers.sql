-- ============================================================================
-- Slice 6: Allocation Driver Definitions & Values
-- ============================================================================

-- Driver definitions (e.g., labor hours, compute usage, transaction volume)
CREATE TABLE driver_definitions (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  config_version_id BIGINT NOT NULL REFERENCES config_versions(id) ON DELETE CASCADE,
  driver_code TEXT NOT NULL,
  name TEXT NOT NULL,
  unit TEXT NOT NULL,
  description TEXT,
  effective_from DATE NOT NULL,
  effective_to DATE,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, driver_code, effective_from)
);

CREATE INDEX idx_driver_definitions_org ON driver_definitions(organization_id);
CREATE INDEX idx_driver_definitions_config ON driver_definitions(config_version_id);
CREATE INDEX idx_driver_definitions_effective ON driver_definitions(organization_id, effective_from, effective_to);

-- Driver values (observed numerator for cost allocation)
CREATE TABLE driver_values (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  driver_definition_id BIGINT NOT NULL REFERENCES driver_definitions(id) ON DELETE CASCADE,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  project_id BIGINT REFERENCES projects(id) ON DELETE SET NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  value NUMERIC NOT NULL CHECK (value >= 0),
  confidence TEXT NOT NULL DEFAULT 'high' CHECK (confidence IN ('high', 'medium', 'low', 'estimated')),
  source_lineage JSONB NOT NULL,
  observation_state TEXT NOT NULL DEFAULT 'observed' CHECK (observation_state IN ('observed', 'missing', 'zero_total', 'late', 'superseded')),
  superseded_by BIGINT REFERENCES driver_values(id) ON DELETE SET NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, driver_definition_id, customer_id, project_id, period_start, period_end)
);

CREATE INDEX idx_driver_values_org ON driver_values(organization_id);
CREATE INDEX idx_driver_values_definition ON driver_values(driver_definition_id);
CREATE INDEX idx_driver_values_customer ON driver_values(customer_id);
CREATE INDEX idx_driver_values_project ON driver_values(project_id);
CREATE INDEX idx_driver_values_period ON driver_values(period_start, period_end);
CREATE INDEX idx_driver_values_state ON driver_values(observation_state);

-- Driver aggregates (total denominator for each driver per period)
CREATE TABLE driver_aggregates (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  driver_definition_id BIGINT NOT NULL REFERENCES driver_definitions(id) ON DELETE CASCADE,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_value NUMERIC NOT NULL CHECK (total_value >= 0),
  non_missing_count INT NOT NULL DEFAULT 0,
  missing_count INT NOT NULL DEFAULT 0,
  zero_total_count INT NOT NULL DEFAULT 0,
  late_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, driver_definition_id, period_start, period_end)
);

CREATE INDEX idx_driver_aggregates_org ON driver_aggregates(organization_id);
CREATE INDEX idx_driver_aggregates_definition ON driver_aggregates(driver_definition_id);
CREATE INDEX idx_driver_aggregates_period ON driver_aggregates(period_start, period_end);
