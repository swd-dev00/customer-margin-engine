-- ============================================================================
-- Slice 4-5: Cost Classification & Contribution Margin
-- ============================================================================

-- Cost classification configuration
CREATE TABLE cost_classifications (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  config_version_id BIGINT NOT NULL REFERENCES config_versions(id) ON DELETE CASCADE,
  classification_code TEXT NOT NULL,
  name TEXT NOT NULL,
  cost_category TEXT NOT NULL CHECK (cost_category IN ('ai_usage', 'cloud', 'software', 'payment_fee', 'contractor', 'support', 'infrastructure', 'opex', 'capex', 'excluded')),
  cost_behavior TEXT NOT NULL CHECK (cost_behavior IN ('variable', 'fixed', 'shared', 'excluded')),
  match_priority INT NOT NULL,
  match_pattern JSONB,
  effective_from DATE NOT NULL,
  effective_to DATE,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_cost_classifications_org ON cost_classifications(organization_id);
CREATE INDEX idx_cost_classifications_config ON cost_classifications(config_version_id);
CREATE INDEX idx_cost_classifications_priority ON cost_classifications(organization_id, match_priority);
CREATE INDEX idx_cost_classifications_category ON cost_classifications(cost_category);

-- Classified costs (cost with assigned classification)
CREATE TABLE classified_costs (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  mapped_cost_id BIGINT NOT NULL REFERENCES mapped_costs(id) ON DELETE CASCADE,
  classification_id BIGINT NOT NULL REFERENCES cost_classifications(id),
  classification_code TEXT NOT NULL,
  cost_category TEXT NOT NULL,
  cost_behavior TEXT NOT NULL CHECK (cost_behavior IN ('direct_variable', 'direct_fixed', 'shared', 'excluded')),
  amount NUMERIC NOT NULL,
  currency TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, mapped_cost_id)
);

CREATE INDEX idx_classified_costs_org ON classified_costs(organization_id);
CREATE INDEX idx_classified_costs_behavior ON classified_costs(cost_behavior);
CREATE INDEX idx_classified_costs_category ON classified_costs(cost_category);

-- Classification exceptions (unmapped or ambiguous classifications)
CREATE TABLE classification_exceptions (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  mapped_cost_id BIGINT NOT NULL REFERENCES mapped_costs(id) ON DELETE CASCADE,
  reason TEXT NOT NULL CHECK (reason IN ('unmapped', 'ambiguous', 'priority_conflict', 'date_conflict')),
  resolution_state TEXT NOT NULL DEFAULT 'pending' CHECK (resolution_state IN ('pending', 'resolved', 'ignored')),
  resolution_action TEXT,
  resolved_by TEXT,
  resolved_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, mapped_cost_id)
);

CREATE INDEX idx_classification_exceptions_org ON classification_exceptions(organization_id);
CREATE INDEX idx_classification_exceptions_state ON classification_exceptions(resolution_state);

-- Contribution margin aggregates (revenue - direct variable costs)
CREATE TABLE contribution_margin_aggregates (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  project_id BIGINT REFERENCES projects(id) ON DELETE SET NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  currency TEXT NOT NULL,
  revenue_amount NUMERIC NOT NULL,
  direct_variable_cost NUMERIC NOT NULL DEFAULT 0,
  contribution_margin_dollars NUMERIC NOT NULL,
  contribution_margin_pct NUMERIC,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, customer_id, project_id, period_start, period_end, currency)
);

CREATE INDEX idx_contrib_margin_org ON contribution_margin_aggregates(organization_id);
CREATE INDEX idx_contrib_margin_customer ON contribution_margin_aggregates(customer_id);
CREATE INDEX idx_contrib_margin_project ON contribution_margin_aggregates(project_id);
CREATE INDEX idx_contrib_margin_period ON contribution_margin_aggregates(period_start, period_end);
