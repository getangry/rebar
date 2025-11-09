class AttributeSchema < ApplicationRecord
  validates :entity_type, presence: true
  validates :version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :schema, presence: true

  validates :entity_type, uniqueness: { scope: :version }

  scope :active, -> { where(active: true) }
  scope :for_entity_type, ->(entity_type) { where(entity_type: entity_type) }

  # Get the active schema for an entity type
  def self.active_schema_for(entity_type)
    for_entity_type(entity_type)
      .active
      .order(version: :desc)
      .first
  end

  # Get latest version number for entity type
  def self.latest_version_for(entity_type)
    for_entity_type(entity_type)
      .maximum(:version) || 0
  end

  # Validate attributes against this schema
  def validate_attributes(attributes)
    require 'json_schemer'

    schemer = JSONSchemer.schema(schema)
    errors = schemer.validate(attributes).to_a

    if errors.any?
      formatted_errors = errors.map do |error|
        pointer = error['data_pointer']
        type = error['type']
        details = error['details'] || error['error']
        "#{pointer}: #{type} - #{details}"
      end.join('; ')

      raise ValidationError, "Schema validation failed: #{formatted_errors}"
    end

    true
  end

  class ValidationError < StandardError; end
end
