class AttributeVersion < ApplicationRecord
  belongs_to :previous_version, class_name: 'AttributeVersion', optional: true

  # Invalidate cache after any save
  after_save :invalidate_cache

  validates :entity_type, presence: true
  validates :subject, presence: true
  validates :subject_id, presence: true
  validates :valid_from, presence: true
  validates :tenant_id, presence: true
  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Scopes
  scope :for_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
  scope :for_entity_type, ->(entity_type) { where(entity_type: entity_type) }
  scope :for_subject, ->(subject, subject_id) { where(subject: subject, subject_id: subject_id) }
  scope :current, -> { where("valid_until = 'infinity'::timestamptz") }
  scope :historical, -> { where("valid_until < 'infinity'::timestamptz") }
  scope :valid_at, ->(timestamp) { where('? BETWEEN valid_from AND valid_until', timestamp) }
  scope :since, ->(time) { where('valid_from >= ?', time) }
  scope :recent, -> { order(created_at: :desc) }

  # Get current attributes for a subject
  def self.current_for(subject, subject_id, tenant_id: 'default')
    for_tenant(tenant_id)
      .for_subject(subject, subject_id)
      .current
      .first
  end

  # Get attributes at a specific point in time
  def self.at_time(subject, subject_id, timestamp, tenant_id: 'default')
    for_tenant(tenant_id)
      .for_subject(subject, subject_id)
      .valid_at(timestamp)
      .first
  end

  # Get version history for a subject
  def self.history_for(subject, subject_id, tenant_id: 'default')
    for_tenant(tenant_id)
      .for_subject(subject, subject_id)
      .order(version_number: :desc)
  end

  # Create a new version using the stored function
  def self.create_version!(
    entity_type:,
    subject:,
    subject_id:,
    metadata: {},
    tenant_id: 'default',
    created_by: nil,
    change_reason: nil,
    max_requests: nil,
    current_requests: nil,
    risk_level: nil,
    requires_mfa: nil
  )
    # Validate against schema if exists
    schema = AttributeSchema.active_schema_for(entity_type)
    schema&.validate_attributes(metadata)

    # Call stored function
    result = connection.execute(<<~SQL)
      SELECT create_attribute_version(
        #{connection.quote(entity_type)},
        #{connection.quote(subject)},
        #{connection.quote(subject_id)},
        #{connection.quote(metadata.to_json)},
        #{connection.quote(created_by)},
        #{connection.quote(change_reason)},
        #{connection.quote(tenant_id)},
        #{max_requests || 'NULL'},
        #{current_requests || 'NULL'},
        #{connection.quote(risk_level)},
        #{requires_mfa.nil? ? 'NULL' : requires_mfa}
      ) as id
    SQL

    version_id = result.first['id']

    # Invalidate cache for this entity
    AttributeCache.invalidate_entity(subject, subject_id, tenant_id: tenant_id)

    find(version_id)
  end

  # Check if this is the current version
  def current?
    is_current || valid_until == Float::INFINITY || valid_until.to_s == 'Infinity'
  end

  # Get the full attribute chain (current and previous versions)
  def version_chain
    chain = [self]
    current = self

    while current.previous_version_id
      current = AttributeVersion.find_by(id: current.previous_version_id)
      break unless current
      chain << current
    end

    chain
  end

  # Get all metadata merged (useful for inheritance)
  def merged_metadata
    metadata.deep_dup
  end

  # Check if metadata value changed from previous version
  def changed_metadata
    return metadata if previous_version.nil?

    prev_attrs = previous_version.metadata
    curr_attrs = metadata

    changes = {}

    # Find added/changed keys
    curr_attrs.each do |key, value|
      if !prev_attrs.key?(key) || prev_attrs[key] != value
        changes[key] = { old: prev_attrs[key], new: value }
      end
    end

    # Find removed keys
    prev_attrs.each do |key, value|
      if !curr_attrs.key?(key)
        changes[key] = { old: value, new: nil }
      end
    end

    changes
  end

  private

  def invalidate_cache
    AttributeCache.invalidate_entity(subject, subject_id, tenant_id: tenant_id)
  end
end
