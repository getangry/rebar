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

ActiveRecord::Schema[8.1].define(version: 2025_11_08_075847) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

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
  add_foreign_key "service_grants", "service_accounts"
  add_foreign_key "service_tokens", "service_accounts"
end
