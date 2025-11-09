class CreateAttributeSystem < ActiveRecord::Migration[8.1]
  def up
    # Attribute Schemas - Define structure and validation rules for attributes
    create_table :attribute_schemas, id: :uuid do |t|
      t.string :entity_type, null: false
      t.integer :version, null: false, default: 1
      t.jsonb :schema, null: false, default: {}
      t.boolean :active, default: true
      t.text :description
      t.string :created_by
      t.timestamps

      t.index [:entity_type, :version], unique: true
      t.index [:entity_type, :active], where: "active = true"
    end

    # Attribute Versions - Temporal storage for entity attributes
    create_table :attribute_versions, id: :uuid do |t|
      # Entity reference
      t.string :entity_type, null: false
      t.string :subject, null: false
      t.string :subject_id, null: false

      # Temporal tracking
      t.timestamptz :valid_from, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamptz :valid_until, default: -> { "'infinity'::timestamptz" }

      # Hot attributes (indexed for fast policy evaluation)
      t.integer :max_requests
      t.integer :current_requests, default: 0
      t.string :risk_level
      t.boolean :requires_mfa, default: false

      # Cold attributes (flexible JSONB storage)
      t.jsonb :attributes, null: false, default: {}

      # Audit metadata
      t.string :created_by
      t.text :change_reason

      # Versioning
      t.uuid :previous_version_id
      t.integer :version_number, null: false, default: 1

      # Tenant isolation
      t.string :tenant_id, null: false, default: 'default'

      # Computed column for easier partitioning later
      t.virtual :is_current, type: :boolean, as: "(valid_until = 'infinity'::timestamptz)", stored: true

      t.timestamps null: false

      # Foreign key to previous version
      t.foreign_key :attribute_versions, column: :previous_version_id
    end

    # Indexes for fast lookups
    # Current attributes (hot path - most queries)
    add_index :attribute_versions,
              [:subject_id, :valid_until],
              name: 'idx_attr_current_lookup',
              where: "valid_until = 'infinity'::timestamptz",
              include: [:attributes, :max_requests, :current_requests, :requires_mfa]

    # Point-in-time queries (audit path)
    add_index :attribute_versions,
              [:subject_id, :valid_from, :valid_until],
              name: 'idx_attr_point_in_time'

    # Policy evaluation (use is_current for filtering)
    add_index :attribute_versions,
              [:subject, :subject_id, :is_current],
              name: 'idx_attr_policy_eval',
              where: "is_current = true"

    # JSONB queries
    add_index :attribute_versions, :attributes, using: :gin, name: 'idx_attr_jsonb'

    # Tenant isolation
    add_index :attribute_versions, [:tenant_id, :entity_type, :subject_id]

    # Relationship Attributes - Attributes on relationships (tuples)
    create_table :rel_tuple_attributes, id: :uuid do |t|
      # Foreign key to relationship
      t.uuid :tuple_id, null: false

      # Temporal tracking
      t.timestamptz :valid_from, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamptz :valid_until, default: -> { "'infinity'::timestamptz" }

      # Hot attributes
      t.integer :usage_count, default: 0
      t.integer :max_usage
      t.string :granted_by
      t.boolean :approval_required, default: false
      t.string :approval_status

      # Cold attributes
      t.jsonb :attributes, null: false, default: {}

      # Audit
      t.string :created_by
      t.text :change_reason

      # Versioning
      t.uuid :previous_version_id
      t.integer :version_number, null: false, default: 1

      # Tenant isolation
      t.string :tenant_id, null: false, default: 'default'

      # Computed
      t.virtual :is_current, type: :boolean, as: "(valid_until = 'infinity'::timestamptz)", stored: true

      t.timestamps null: false

      t.foreign_key :rel_tuples, column: :tuple_id, on_delete: :cascade
      t.foreign_key :rel_tuple_attributes, column: :previous_version_id
    end

    # Indexes for relationship attributes
    add_index :rel_tuple_attributes,
              [:tuple_id, :valid_until],
              name: 'idx_tuple_attr_current',
              where: "valid_until = 'infinity'::timestamptz"

    add_index :rel_tuple_attributes,
              [:tuple_id, :valid_from, :valid_until],
              name: 'idx_tuple_attr_temporal'

    # Function to create new attribute version (closes previous version)
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

    # Function for relationship attributes
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
  end

  def down
    execute "DROP FUNCTION IF EXISTS create_attribute_version"
    execute "DROP FUNCTION IF EXISTS create_rel_tuple_attribute_version"

    drop_table :rel_tuple_attributes
    drop_table :attribute_versions
    drop_table :attribute_schemas
  end
end
