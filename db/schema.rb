# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_09_045303) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  create_table "analytics_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor"
    t.string "actor_id"
    t.boolean "allowed"
    t.uuid "api_key_id"
    t.datetime "created_at", precision: nil, null: false
    t.string "endpoint"
    t.string "event_type", null: false
    t.string "ip_address"
    t.integer "latency_ms"
    t.jsonb "metadata", default: {}
    t.string "permission"
    t.uuid "service_id"
    t.string "subject"
    t.string "subject_id"
    t.string "tenant_id", default: "default", null: false
    t.index ["api_key_id", "created_at"], name: "idx_analytics_apikey_time"
    t.index ["event_type", "created_at"], name: "idx_analytics_event_time"
    t.index ["service_id", "created_at"], name: "idx_analytics_service_time"
    t.index ["subject", "permission"], name: "idx_analytics_permission"
    t.index ["tenant_id", "created_at"], name: "idx_analytics_tenant_time"
    t.index ["tenant_id", "event_type", "allowed"], name: "idx_analytics_checks"
  end

  create_table "api_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "key_hash", null: false
    t.string "key_prefix", null: false
    t.datetime "last_used_at"
    t.string "name"
    t.uuid "service_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0, null: false
    t.index ["key_hash"], name: "index_api_keys_on_key_hash", unique: true
    t.index ["last_used_at"], name: "index_api_keys_on_last_used_at"
    t.index ["service_id", "active"], name: "index_api_keys_on_service_id_and_active"
    t.index ["service_id"], name: "index_api_keys_on_service_id"
  end

  create_table "attribute_schemas", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "created_by"
    t.text "description"
    t.string "entity_type", null: false
    t.jsonb "schema", default: {}, null: false
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["entity_type", "active"], name: "index_attribute_schemas_on_entity_type_and_active", where: "(active = true)"
    t.index ["entity_type", "version"], name: "index_attribute_schemas_on_entity_type_and_version", unique: true
  end

  create_table "attribute_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "change_reason"
    t.datetime "created_at", null: false
    t.string "created_by"
    t.integer "current_requests", default: 0
    t.string "entity_type", null: false
    t.virtual "is_current", type: :boolean, as: "(valid_until = 'infinity'::timestamp with time zone)", stored: true
    t.integer "max_requests"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "previous_version_id"
    t.boolean "requires_mfa", default: false
    t.string "risk_level"
    t.string "subject", null: false
    t.string "subject_id", null: false
    t.string "tenant_id", default: "default", null: false
    t.datetime "updated_at", null: false
    t.timestamptz "valid_from", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.timestamptz "valid_until", default: ::Float::INFINITY
    t.integer "version_number", default: 1, null: false
    t.index ["metadata"], name: "idx_attr_jsonb", using: :gin
    t.index ["subject", "subject_id", "is_current"], name: "idx_attr_policy_eval", where: "(is_current = true)"
    t.index ["subject_id", "valid_from", "valid_until"], name: "idx_attr_point_in_time"
    t.index ["subject_id", "valid_until"], name: "idx_attr_current_lookup", where: "(valid_until = 'infinity'::timestamp with time zone)", include: ["metadata", "max_requests", "current_requests", "requires_mfa"]
    t.index ["tenant_id", "entity_type", "subject_id"], name: "idx_on_tenant_id_entity_type_subject_id_0eb843a023"
  end

  create_table "audit_logs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.string "actor"
    t.string "actor_id"
    t.string "actor_rel"
    t.string "actor_user_id"
    t.jsonb "after_state"
    t.jsonb "before_state"
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}
    t.string "object_id"
    t.string "reason"
    t.string "relation"
    t.string "resource_type", null: false
    t.string "service_id", null: false
    t.string "subject"
    t.string "tenant_id", default: "default", null: false
    t.string "user_agent"
    t.index ["tenant_id", "action"], name: "idx_audit_action"
    t.index ["tenant_id", "actor", "actor_id"], name: "idx_audit_actor"
    t.index ["tenant_id", "created_at"], name: "idx_audit_tenant_time"
    t.index ["tenant_id", "service_id"], name: "idx_audit_tenant_service"
    t.index ["tenant_id", "subject", "object_id"], name: "idx_audit_resource"
  end

  create_table "rel_tuple_attributes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "approval_required", default: false
    t.string "approval_status"
    t.text "change_reason"
    t.datetime "created_at", null: false
    t.string "created_by"
    t.string "granted_by"
    t.virtual "is_current", type: :boolean, as: "(valid_until = 'infinity'::timestamp with time zone)", stored: true
    t.integer "max_usage"
    t.jsonb "metadata", default: {}, null: false
    t.uuid "previous_version_id"
    t.string "tenant_id", default: "default", null: false
    t.uuid "tuple_id", null: false
    t.datetime "updated_at", null: false
    t.integer "usage_count", default: 0
    t.timestamptz "valid_from", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.timestamptz "valid_until", default: ::Float::INFINITY
    t.integer "version_number", default: 1, null: false
    t.index ["tuple_id", "valid_from", "valid_until"], name: "idx_tuple_attr_temporal"
    t.index ["tuple_id", "valid_until"], name: "idx_tuple_attr_current", where: "(valid_until = 'infinity'::timestamp with time zone)"
  end

  create_table "rel_tuples", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "actor", null: false
    t.string "actor_id", null: false
    t.string "actor_rel"
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}
    t.string "relation", null: false
    t.string "subject", null: false
    t.string "subject_id", null: false
    t.string "tenant_id", default: "default", null: false
    t.datetime "updated_at", null: false
    t.index "tenant_id, subject, subject_id, relation, actor, actor_id, COALESCE(actor_rel, ''::character varying)", name: "uq_rt_fact", unique: true
    t.index ["actor"], name: "index_rel_tuples_on_actor"
    t.index ["actor_id"], name: "index_rel_tuples_on_actor_id"
    t.index ["relation"], name: "index_rel_tuples_on_relation"
    t.index ["subject"], name: "index_rel_tuples_on_subject"
    t.index ["subject_id"], name: "index_rel_tuples_on_subject_id"
    t.index ["tenant_id", "actor", "actor_id", "subject", "subject_id", "relation"], name: "idx_rt_actor_covering"
    t.index ["tenant_id", "actor", "actor_id", "subject"], name: "idx_rt_actor_subject", where: "((subject)::text = 'group'::text)"
    t.index ["tenant_id", "actor", "actor_id"], name: "idx_rt_actor"
    t.index ["tenant_id", "relation", "actor", "actor_id"], name: "idx_rt_parent_lookup", where: "((relation)::text = 'parent'::text)"
    t.index ["tenant_id", "subject", "relation", "actor"], name: "idx_rt_subj_rel_actor"
    t.index ["tenant_id", "subject", "subject_id", "relation"], name: "idx_rt_subj_rel"
    t.index ["tenant_id"], name: "index_rel_tuples_on_tenant_id"
  end

  create_table "service_accounts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_service_accounts_on_external_id", unique: true
  end

  create_table "service_grants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "action", null: false
    t.string "actor"
    t.string "actor_prefix"
    t.datetime "created_at", null: false
    t.integer "rate_limit_qps"
    t.string "relations", array: true
    t.uuid "service_account_id", null: false
    t.string "subject"
    t.string "subject_prefix"
    t.string "tenant_id"
    t.datetime "updated_at", null: false
    t.index ["service_account_id", "action"], name: "index_service_grants_on_service_account_id_and_action"
    t.index ["service_account_id"], name: "index_service_grants_on_service_account_id"
  end

  create_table "service_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.uuid "service_account_id", null: false
    t.string "token_hash", null: false
    t.datetime "updated_at", null: false
    t.index ["service_account_id"], name: "index_service_tokens_on_service_account_id"
    t.index ["token_hash"], name: "index_service_tokens_on_token_hash", unique: true
  end

  create_table "services", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "allowed_relations", default: []
    t.jsonb "allowed_subjects", default: []
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.jsonb "schemas", default: ["default"]
    t.string "tenant_id", default: "default", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_services_on_active"
    t.index ["tenant_id", "name"], name: "index_services_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_services_on_tenant_id"
  end

  add_foreign_key "api_keys", "services"
  add_foreign_key "attribute_versions", "attribute_versions", column: "previous_version_id"
  add_foreign_key "rel_tuple_attributes", "rel_tuple_attributes", column: "previous_version_id"
  add_foreign_key "rel_tuple_attributes", "rel_tuples", column: "tuple_id", on_delete: :cascade
  add_foreign_key "service_grants", "service_accounts"
  add_foreign_key "service_tokens", "service_accounts"
end
