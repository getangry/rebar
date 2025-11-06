class CreateServiceAuthz < ActiveRecord::Migration[7.1]
  def change
    create_table :service_accounts, id: :bigserial do |t|
      t.string :name, null: false
      t.string :external_id, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :service_accounts, :external_id, unique: true

    create_table :service_grants, id: :bigserial do |t|
      t.references :service_account, null: false
      t.string  :action, null: false
      t.string  :tenant_id
      t.string  :subject
      t.string  :relations, array: true
      t.string  :subject_prefix
      t.string  :actor
      t.string  :actor_prefix
      t.integer :rate_limit_qps
      t.timestamps
    end
    add_index :service_grants, [:service_account_id, :action]

    create_table :service_tokens, id: :bigserial do |t|
      t.references :service_account, null: false
      t.string :token_hash, null: false
      t.datetime :expires_at
      t.timestamps
    end
    add_index :service_tokens, :token_hash, unique: true
  end
end
