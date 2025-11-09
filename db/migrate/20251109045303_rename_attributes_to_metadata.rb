class RenameAttributesToMetadata < ActiveRecord::Migration[8.1]
  def up
    # Rename columns
    rename_column :attribute_versions, :attributes, :metadata
    rename_column :rel_tuple_attributes, :attributes, :metadata

    # Drop existing stored procedures first
    execute "DROP FUNCTION IF EXISTS create_attribute_version(VARCHAR,VARCHAR,VARCHAR,JSONB,VARCHAR,TEXT,VARCHAR,INTEGER,INTEGER,VARCHAR,BOOLEAN)"
    execute "DROP FUNCTION IF EXISTS create_rel_tuple_attribute_version(UUID,JSONB,VARCHAR,TEXT,VARCHAR,INTEGER,INTEGER,VARCHAR,BOOLEAN,VARCHAR)"

    # Create stored procedures with 'metadata' parameter name
    execute <<-SQL
      CREATE OR REPLACE FUNCTION create_attribute_version(
        p_entity_type VARCHAR,
        p_subject VARCHAR,
        p_subject_id VARCHAR,
        p_metadata JSONB,
        p_created_by VARCHAR DEFAULT NULL,
        p_change_reason TEXT DEFAULT NULL,
        p_tenant_id VARCHAR DEFAULT 'default',
        p_max_requests INTEGER DEFAULT NULL,
        p_current_requests INTEGER DEFAULT NULL,
        p_risk_level VARCHAR DEFAULT NULL,
        p_requires_mfa BOOLEAN DEFAULT NULL
      )
      RETURNS UUID AS $$
      DECLARE
        v_current_version UUID;
        v_new_version UUID;
        v_next_version_number INTEGER;
      BEGIN
        -- Find and lock current version
        SELECT id, version_number
        INTO v_current_version, v_next_version_number
        FROM attribute_versions
        WHERE entity_type = p_entity_type
          AND subject = p_subject
          AND subject_id = p_subject_id
          AND tenant_id = p_tenant_id
          AND valid_until = 'infinity'::timestamptz
        FOR UPDATE;

        -- Increment version number
        v_next_version_number := COALESCE(v_next_version_number, 0) + 1;

        -- Close current version if exists
        IF v_current_version IS NOT NULL THEN
          UPDATE attribute_versions
          SET valid_until = NOW()
          WHERE id = v_current_version;
        END IF;

        -- Create new version
        INSERT INTO attribute_versions (
          entity_type, subject, subject_id,
          metadata, created_by, change_reason,
          previous_version_id, version_number, tenant_id,
          max_requests, current_requests, risk_level, requires_mfa,
          created_at, updated_at
        )
        VALUES (
          p_entity_type, p_subject, p_subject_id,
          p_metadata, p_created_by, p_change_reason,
          v_current_version, v_next_version_number, p_tenant_id,
          p_max_requests, p_current_requests, p_risk_level, p_requires_mfa,
          NOW(), NOW()
        )
        RETURNING id INTO v_new_version;

        RETURN v_new_version;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE OR REPLACE FUNCTION create_rel_tuple_attribute_version(
        p_tuple_id UUID,
        p_metadata JSONB,
        p_created_by VARCHAR DEFAULT NULL,
        p_change_reason TEXT DEFAULT NULL,
        p_tenant_id VARCHAR DEFAULT 'default',
        p_usage_count INTEGER DEFAULT NULL,
        p_max_usage INTEGER DEFAULT NULL,
        p_granted_by VARCHAR DEFAULT NULL,
        p_approval_required BOOLEAN DEFAULT NULL,
        p_approval_status VARCHAR DEFAULT NULL
      )
      RETURNS UUID AS $$
      DECLARE
        v_current_version UUID;
        v_new_version UUID;
        v_next_version_number INTEGER;
      BEGIN
        -- Find and lock current version
        SELECT id, version_number
        INTO v_current_version, v_next_version_number
        FROM rel_tuple_attributes
        WHERE tuple_id = p_tuple_id
          AND tenant_id = p_tenant_id
          AND valid_until = 'infinity'::timestamptz
        FOR UPDATE;

        -- Increment version number
        v_next_version_number := COALESCE(v_next_version_number, 0) + 1;

        -- Close current version if exists
        IF v_current_version IS NOT NULL THEN
          UPDATE rel_tuple_attributes
          SET valid_until = NOW()
          WHERE id = v_current_version;
        END IF;

        -- Create new version
        INSERT INTO rel_tuple_attributes (
          tuple_id, metadata, created_by, change_reason,
          previous_version_id, version_number, tenant_id,
          usage_count, max_usage, granted_by,
          approval_required, approval_status,
          created_at, updated_at
        )
        VALUES (
          p_tuple_id, p_metadata, p_created_by, p_change_reason,
          v_current_version, v_next_version_number, p_tenant_id,
          p_usage_count, p_max_usage, p_granted_by,
          p_approval_required, p_approval_status,
          NOW(), NOW()
        )
        RETURNING id INTO v_new_version;

        RETURN v_new_version;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Update indexes
    remove_index :attribute_versions, name: 'idx_attr_jsonb'
    add_index :attribute_versions, :metadata, using: :gin, name: 'idx_attr_jsonb'

    # Update covering index
    remove_index :attribute_versions, name: 'idx_attr_current_lookup'
    add_index :attribute_versions,
              [:subject_id, :valid_until],
              name: 'idx_attr_current_lookup',
              where: "valid_until = 'infinity'::timestamptz",
              include: [:metadata, :max_requests, :current_requests, :requires_mfa]
  end

  def down
    # Revert indexes
    remove_index :attribute_versions, name: 'idx_attr_current_lookup'
    add_index :attribute_versions,
              [:subject_id, :valid_until],
              name: 'idx_attr_current_lookup',
              where: "valid_until = 'infinity'::timestamptz",
              include: [:attributes, :max_requests, :current_requests, :requires_mfa]

    remove_index :attribute_versions, name: 'idx_attr_jsonb'
    add_index :attribute_versions, :attributes, using: :gin, name: 'idx_attr_jsonb'

    # Revert stored procedures
    execute <<-SQL
      CREATE OR REPLACE FUNCTION create_attribute_version(
        p_entity_type VARCHAR,
        p_subject VARCHAR,
        p_subject_id VARCHAR,
        p_attributes JSONB,
        p_created_by VARCHAR DEFAULT NULL,
        p_change_reason TEXT DEFAULT NULL,
        p_tenant_id VARCHAR DEFAULT 'default',
        p_max_requests INTEGER DEFAULT NULL,
        p_current_requests INTEGER DEFAULT NULL,
        p_risk_level VARCHAR DEFAULT NULL,
        p_requires_mfa BOOLEAN DEFAULT NULL
      )
      RETURNS UUID AS $$
      DECLARE
        v_current_version UUID;
        v_new_version UUID;
        v_next_version_number INTEGER;
      BEGIN
        SELECT id, version_number
        INTO v_current_version, v_next_version_number
        FROM attribute_versions
        WHERE entity_type = p_entity_type
          AND subject = p_subject
          AND subject_id = p_subject_id
          AND tenant_id = p_tenant_id
          AND valid_until = 'infinity'::timestamptz
        FOR UPDATE;

        v_next_version_number := COALESCE(v_next_version_number, 0) + 1;

        IF v_current_version IS NOT NULL THEN
          UPDATE attribute_versions
          SET valid_until = NOW()
          WHERE id = v_current_version;
        END IF;

        INSERT INTO attribute_versions (
          entity_type, subject, subject_id,
          attributes, created_by, change_reason,
          previous_version_id, version_number, tenant_id,
          max_requests, current_requests, risk_level, requires_mfa,
          created_at, updated_at
        )
        VALUES (
          p_entity_type, p_subject, p_subject_id,
          p_attributes, p_created_by, p_change_reason,
          v_current_version, v_next_version_number, p_tenant_id,
          p_max_requests, p_current_requests, p_risk_level, p_requires_mfa,
          NOW(), NOW()
        )
        RETURNING id INTO v_new_version;

        RETURN v_new_version;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE OR REPLACE FUNCTION create_rel_tuple_attribute_version(
        p_tuple_id UUID,
        p_attributes JSONB,
        p_created_by VARCHAR DEFAULT NULL,
        p_change_reason TEXT DEFAULT NULL,
        p_tenant_id VARCHAR DEFAULT 'default',
        p_usage_count INTEGER DEFAULT NULL,
        p_max_usage INTEGER DEFAULT NULL,
        p_granted_by VARCHAR DEFAULT NULL,
        p_approval_required BOOLEAN DEFAULT NULL,
        p_approval_status VARCHAR DEFAULT NULL
      )
      RETURNS UUID AS $$
      DECLARE
        v_current_version UUID;
        v_new_version UUID;
        v_next_version_number INTEGER;
      BEGIN
        SELECT id, version_number
        INTO v_current_version, v_next_version_number
        FROM rel_tuple_attributes
        WHERE tuple_id = p_tuple_id
          AND tenant_id = p_tenant_id
          AND valid_until = 'infinity'::timestamptz
        FOR UPDATE;

        v_next_version_number := COALESCE(v_next_version_number, 0) + 1;

        IF v_current_version IS NOT NULL THEN
          UPDATE rel_tuple_attributes
          SET valid_until = NOW()
          WHERE id = v_current_version;
        END IF;

        INSERT INTO rel_tuple_attributes (
          tuple_id, attributes, created_by, change_reason,
          previous_version_id, version_number, tenant_id,
          usage_count, max_usage, granted_by,
          approval_required, approval_status,
          created_at, updated_at
        )
        VALUES (
          p_tuple_id, p_attributes, p_created_by, p_change_reason,
          v_current_version, v_next_version_number, p_tenant_id,
          p_usage_count, p_max_usage, p_granted_by,
          p_approval_required, p_approval_status,
          NOW(), NOW()
        )
        RETURNING id INTO v_new_version;

        RETURN v_new_version;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    # Rename columns back
    rename_column :rel_tuple_attributes, :metadata, :attributes
    rename_column :attribute_versions, :metadata, :attributes
  end
end
