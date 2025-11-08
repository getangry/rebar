class EnableUuidExtension < ActiveRecord::Migration[8.1]
  def change
    # Enable pgcrypto extension for UUID support
    enable_extension 'pgcrypto'
  end
end
