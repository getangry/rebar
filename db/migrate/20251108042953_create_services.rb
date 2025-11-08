class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.text :description
      t.string :api_key_hash, null: false
      t.jsonb :allowed_subjects, default: []
      t.jsonb :allowed_relations, default: []
      t.jsonb :metadata, default: {}
      t.string :schema_name, default: 'default'
      t.boolean :active, default: true, null: false
      t.string :tenant_id, null: false, default: 'default'

      t.timestamps
    end

    add_index :services, [:tenant_id, :name], unique: true
    add_index :services, :api_key_hash, unique: true
    add_index :services, :active
  end
end
