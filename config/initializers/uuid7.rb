# Configure ActiveRecord to use UUIDv7 for primary keys
# UUIDv7 provides time-sortable UUIDs which are better for database performance

require 'uuid7'

# Override ActiveRecord::Base to use UUIDv7 for primary keys
module ActiveRecord
  module UUIDv7Generator
    extend ActiveSupport::Concern

    included do
      before_create :generate_uuid_v7_id, if: :new_record?
    end

    private

    def generate_uuid_v7_id
      # Only generate if ID is not already set and this model uses UUID primary keys
      if respond_to?(:id=) && id.nil? && self.class.primary_key == 'id'
        column = self.class.columns_hash['id']
        if column && column.sql_type == 'uuid'
          self.id = UUID7.generate
        end
      end
    end
  end
end

# Include in ApplicationRecord so all models inherit it
ActiveSupport.on_load(:active_record) do
  include ActiveRecord::UUIDv7Generator
end
