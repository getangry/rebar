class CreateApiKeys < ActiveRecord::Migration[8.1]
  def change
    create_table :api_keys, id: :uuid do |t|
      t.uuid :service_id, null: false, index: true
      t.string :key_hash, null: false
      t.string :key_prefix, null: false
      t.string :name
      t.datetime :last_used_at
      t.integer :usage_count, default: 0, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :api_keys, :key_hash, unique: true
    add_index :api_keys, [:service_id, :active]
    add_index :api_keys, :last_used_at
    add_foreign_key :api_keys, :services
  end
end
