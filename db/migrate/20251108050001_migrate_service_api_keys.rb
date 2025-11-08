class MigrateServiceApiKeys < ActiveRecord::Migration[8.1]
  def change
    # Data migration not needed for fresh database setup
    # Services now create API keys via after_create callback
  end
end
