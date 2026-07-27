-- ============================================================================
-- Slice 1: Multi-tenancy Foundation & Import Infrastructure
-- ============================================================================

-- Organizations (tenants)
CREATE TABLE organizations (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_organizations_slug ON organizations(slug);

-- Customers (belong to organizations)
CREATE TABLE customers (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  external_id TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, external_id)
);

CREATE INDEX idx_customers_org ON customers(organization_id);
CREATE INDEX idx_customers_external_id ON customers(organization_id, external_id);

-- Projects (optional; belong to customers)
CREATE TABLE projects (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  customer_id BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  external_id TEXT NOT NULL,
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, external_id)
);

CREATE INDEX idx_projects_org ON projects(organization_id);
CREATE INDEX idx_projects_customer ON projects(customer_id);
CREATE INDEX idx_projects_external_id ON projects(organization_id, external_id);

-- Import sources (vendor metadata)
CREATE TABLE import_sources (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  vendor_name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  source_type TEXT NOT NULL CHECK (source_type IN ('revenue', 'cost')),
  config JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, vendor_name, source_type)
);

CREATE INDEX idx_import_sources_org ON import_sources(organization_id);

-- Import batches (atomic groups of records)
CREATE TABLE import_batches (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  import_source_id BIGINT NOT NULL REFERENCES import_sources(id) ON DELETE CASCADE,
  batch_id TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'completed', 'failed')),
  record_count INT NOT NULL DEFAULT 0,
  imported_at TIMESTAMP,
  error_message TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  updated_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, import_source_id, batch_id)
);

CREATE INDEX idx_import_batches_org ON import_batches(organization_id);
CREATE INDEX idx_import_batches_source ON import_batches(import_source_id);
CREATE INDEX idx_import_batches_status ON import_batches(status);

-- Raw import records (one per raw source record)
CREATE TABLE raw_import_records (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  import_batch_id BIGINT NOT NULL REFERENCES import_batches(id) ON DELETE CASCADE,
  raw_data JSONB NOT NULL,
  source_id TEXT NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, import_batch_id, source_id)
);

CREATE INDEX idx_raw_import_records_batch ON raw_import_records(import_batch_id);
CREATE INDEX idx_raw_import_records_org ON raw_import_records(organization_id);

-- Configuration versions (immutable versioned config, never edited)
CREATE TABLE config_versions (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  config_type TEXT NOT NULL CHECK (config_type IN ('revenue_mapping', 'cost_classification', 'allocation_rules', 'driver_definitions')),
  version_number INT NOT NULL,
  content JSONB NOT NULL,
  fingerprint TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'approved', 'retired')),
  effective_from DATE NOT NULL,
  effective_to DATE,
  approved_by TEXT,
  approved_at TIMESTAMP,
  retired_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(organization_id, config_type, version_number)
);

CREATE INDEX idx_config_versions_org ON config_versions(organization_id);
CREATE INDEX idx_config_versions_type ON config_versions(organization_id, config_type, status);
CREATE INDEX idx_config_versions_effective ON config_versions(organization_id, config_type, effective_from, effective_to);

-- Configuration fingerprint audit
CREATE TABLE config_fingerprints (
  id BIGSERIAL PRIMARY KEY,
  config_version_id BIGINT NOT NULL REFERENCES config_versions(id) ON DELETE CASCADE,
  hash_algorithm TEXT NOT NULL DEFAULT 'sha256',
  fingerprint TEXT NOT NULL,
  verified_at TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_config_fingerprints_version ON config_fingerprints(config_version_id);
