-- ============================================================================
-- Hardening: Append-Only Raw Evidence & Explicit Corrections
-- ============================================================================

-- A deterministic payload fingerprint makes source evidence comparison explicit.
-- The append-only trigger below prevents the generated value or its source JSON
-- from being changed in place.
ALTER TABLE raw_import_records
  ADD COLUMN raw_hash TEXT
  GENERATED ALWAYS AS (
    encode(sha256(convert_to(raw_data::text, 'UTF8')), 'hex')
  ) STORED;

CREATE UNIQUE INDEX uq_raw_import_records_organization_id_id
  ON raw_import_records(organization_id, id);

-- Corrections retain new evidence without replacing the original source row.
CREATE TABLE raw_import_record_corrections (
  id BIGSERIAL PRIMARY KEY,
  organization_id BIGINT NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  raw_record_id BIGINT NOT NULL,
  supersedes_correction_id BIGINT,
  raw_data JSONB NOT NULL,
  raw_hash TEXT GENERATED ALWAYS AS (
    encode(sha256(convert_to(raw_data::text, 'UTF8')), 'hex')
  ) STORED,
  correction_reason TEXT NOT NULL CHECK (length(trim(correction_reason)) > 0),
  recorded_by TEXT NOT NULL CHECK (length(trim(recorded_by)) > 0),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (organization_id, raw_record_id, id),
  FOREIGN KEY (organization_id, raw_record_id)
    REFERENCES raw_import_records(organization_id, id)
    ON DELETE RESTRICT,
  FOREIGN KEY (organization_id, raw_record_id, supersedes_correction_id)
    REFERENCES raw_import_record_corrections(organization_id, raw_record_id, id)
    ON DELETE RESTRICT
);

CREATE INDEX idx_raw_import_record_corrections_org
  ON raw_import_record_corrections(organization_id);
CREATE INDEX idx_raw_import_record_corrections_raw_record
  ON raw_import_record_corrections(raw_record_id);
CREATE INDEX idx_raw_import_record_corrections_supersedes
  ON raw_import_record_corrections(supersedes_correction_id);

CREATE OR REPLACE FUNCTION reject_append_only_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
  RAISE EXCEPTION
    USING
      ERRCODE = '55000',
      MESSAGE = format('%I is append-only; insert a correction row instead', TG_TABLE_NAME);
END
$function$;

CREATE TRIGGER raw_import_records_append_only
BEFORE UPDATE OR DELETE ON raw_import_records
FOR EACH ROW
EXECUTE FUNCTION reject_append_only_mutation();

CREATE TRIGGER raw_import_record_corrections_append_only
BEFORE UPDATE OR DELETE ON raw_import_record_corrections
FOR EACH ROW
EXECUTE FUNCTION reject_append_only_mutation();
