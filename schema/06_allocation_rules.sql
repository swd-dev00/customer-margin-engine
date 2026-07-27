-- ============================================================================
-- Slice 7: Allocation Rules & Approved Rule Sets
-- ============================================================================

-- Allocation rule sets (versioned immutable policies)
CREATE TABLE allocation_rule_sets (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  config_version_id BIGINT NOT NULL REFERENCES config_versions(id) ON DELETE CASCADE,
  version_number INT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  approval_state TEXT NOT NULL DEFAULT 'draft' CHECK (approval_state IN ('draft', 'approved', 'retired')),
  fingerprint TEXT NOT NULL,
  approved_by TEXT,
  approved_at TIMESTAMP,
  retired_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, version_number)
);

CREATE INDEX idx_allocation_rule_sets_org ON allocation_rule_sets(organization_id);
CREATE INDEX idx_allocation_rule_sets_approval ON allocation_rule_sets(approval_state);

-- Individual allocation rules (within a rule set)
CREATE TABLE allocation_rules (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  rule_set_id BIGINT NOT NULL REFERENCES allocation_rule_sets(id) ON DELETE CASCADE,
  priority INT NOT NULL,
  cost_category TEXT NOT NULL,
  driver_definition_id BIGINT NOT NULL REFERENCES driver_definitions(id),
  fallback_driver_id BIGINT REFERENCES driver_definitions(id),
  eligible_cost_behaviors TEXT[] NOT NULL DEFAULT ARRAY['shared'],
  description TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_allocation_rules_org ON allocation_rules(organization_id);
CREATE INDEX idx_allocation_rules_set ON allocation_rules(rule_set_id);
CREATE INDEX idx_allocation_rules_priority ON allocation_rules(rule_set_id, priority);
CREATE INDEX idx_allocation_rules_category ON allocation_rules(cost_category);
