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

ActiveRecord::Schema[8.1].define(version: 2025_11_08_042953) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.string "actor"
    t.string "actor_id"
    t.string "actor_rel"
    t.string "actor_user_id"
    t.jsonb "after_state"
    t.jsonb "before_state"
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.string "ip_address"
    t.jsonb "metadata"
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

  create_table "rel_tuples", primary_key: "pk", force: :cascade do |t|
    t.string "actor", null: false
    t.string "actor_id", null: false
    t.string "actor_rel"
    t.datetime "created_at", default: -> { "now()" }, null: false
    t.string "id", null: false
    t.string "relation", null: false
    t.string "subject", null: false
    t.string "tenant_id", default: "default", null: false
    t.index "tenant_id, subject, id, relation, actor, actor_id, COALESCE(actor_rel, ''::character varying)", name: "uq_rt_fact", unique: true
    t.index ["tenant_id", "actor", "actor_id", "subject", "id", "relation"], name: "idx_rt_actor_covering"
    t.index ["tenant_id", "actor", "actor_id", "subject"], name: "idx_rt_actor_subject", where: "((subject)::text = 'group'::text)"
    t.index ["tenant_id", "actor", "actor_id"], name: "idx_rt_actor"
    t.index ["tenant_id", "relation", "actor", "actor_id"], name: "idx_rt_parent_lookup", where: "((relation)::text = 'parent'::text)"
    t.index ["tenant_id", "subject", "id", "relation"], name: "idx_rt_subj_rel"
    t.index ["tenant_id", "subject", "relation", "actor"], name: "idx_rt_subj_rel_actor"
  end

  create_table "service_accounts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_service_accounts_on_external_id", unique: true
  end

  create_table "service_grants", force: :cascade do |t|
    t.string "action", null: false
    t.string "actor"
    t.string "actor_prefix"
    t.datetime "created_at", null: false
    t.integer "rate_limit_qps"
    t.string "relations", array: true
    t.bigint "service_account_id", null: false
    t.string "subject"
    t.string "subject_prefix"
    t.string "tenant_id"
    t.datetime "updated_at", null: false
    t.index ["service_account_id", "action"], name: "index_service_grants_on_service_account_id_and_action"
    t.index ["service_account_id"], name: "index_service_grants_on_service_account_id"
  end

  create_table "service_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.bigint "service_account_id", null: false
    t.string "token_hash", null: false
    t.datetime "updated_at", null: false
    t.index ["service_account_id"], name: "index_service_tokens_on_service_account_id"
    t.index ["token_hash"], name: "index_service_tokens_on_token_hash", unique: true
  end

  create_table "services", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.jsonb "allowed_relations", default: []
    t.jsonb "allowed_subjects", default: []
    t.string "api_key_hash", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "metadata", default: {}
    t.string "name", null: false
    t.string "schema_name", default: "default"
    t.string "tenant_id", default: "default", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_services_on_active"
    t.index ["api_key_hash"], name: "index_services_on_api_key_hash", unique: true
    t.index ["tenant_id", "name"], name: "index_services_on_tenant_id_and_name", unique: true
  end
end
