# Configure Rails generators to use UUID primary keys by default
Rails.application.config.generators do |g|
  g.orm :active_record, primary_key_type: :uuid
end
