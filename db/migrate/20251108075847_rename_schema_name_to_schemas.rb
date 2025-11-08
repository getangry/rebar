class RenameSchemaNameToSchemas < ActiveRecord::Migration[8.1]
  def up
    # Add new schemas column as jsonb array
    add_column :services, :schemas, :jsonb, default: ['default']

    # Migrate data from schema_name to schemas
    execute <<-SQL
      UPDATE services
      SET schemas = jsonb_build_array(COALESCE(schema_name, 'default'))
    SQL

    # Remove old column
    remove_column :services, :schema_name
  end

  def down
    # Add back schema_name column
    add_column :services, :schema_name, :string, default: 'default'

    # Migrate data back (take first element of array)
    execute <<-SQL
      UPDATE services
      SET schema_name = COALESCE(schemas->0, '"default"')::text
    SQL

    # Remove schemas column
    remove_column :services, :schemas
  end
end
