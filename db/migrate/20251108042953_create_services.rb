class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :allowed_subjects, default: []
      t.jsonb :allowed_relations, default: []
      t.jsonb :schemas, default: ['default']
      t.jsonb :metadata, default: {}
      t.boolean :active, default: true, null: false
      t.string :tenant_id, null: false, default: 'default'

      t.timestamps
    end

    add_index :services, [:tenant_id, :name], unique: true
    add_index :services, :active
    add_index :services, :tenant_id
  end
end
