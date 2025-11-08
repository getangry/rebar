class CreateServiceAuthz < ActiveRecord::Migration[8.1]
  def change
    create_table :service_accounts, id: :uuid do |t|
      t.string :name, null: false
      t.string :external_id, null: false
      t.string :status, null: false, default: 'active'
      t.timestamps
    end
    add_index :service_accounts, :external_id, unique: true

    create_table :service_grants, id: :uuid do |t|
      t.uuid :service_account_id, null: false, index: true
      t.string :action, null: false
      t.string :tenant_id
      t.string :subject
      t.string :relations, array: true
      t.string :subject_prefix
      t.string :actor
      t.string :actor_prefix
      t.integer :rate_limit_qps
      t.timestamps
    end
    add_index :service_grants, [:service_account_id, :action]
    add_foreign_key :service_grants, :service_accounts

    create_table :service_tokens, id: :uuid do |t|
      t.uuid :service_account_id, null: false, index: true
      t.string :token_hash, null: false
      t.datetime :expires_at
      t.timestamps
    end
    add_index :service_tokens, :token_hash, unique: true
    add_foreign_key :service_tokens, :service_accounts
  end
end
