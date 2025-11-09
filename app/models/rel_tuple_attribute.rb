class RelTupleAttribute < ApplicationRecord
  belongs_to :tuple, class_name: 'RelTuple', foreign_key: :tuple_id
  belongs_to :previous_version, class_name: 'RelTupleAttribute', optional: true

  # Invalidate cache after any save
  after_save :invalidate_cache

  validates :tuple_id, presence: true
  validates :valid_from, presence: true
  validates :tenant_id, presence: true
  validates :version_number, presence: true, numericality: { only_integer: true, greater_than: 0 }

  # Scopes
  scope :for_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
  scope :for_tuple, ->(tuple_id) { where(tuple_id: tuple_id) }
  scope :current, -> { where("valid_until = 'infinity'::timestamptz") }
  scope :historical, -> { where("valid_until < 'infinity'::timestamptz") }
  scope :valid_at, ->(timestamp) { where('? BETWEEN valid_from AND valid_until', timestamp) }
  scope :expired, -> { where('valid_until <= ?', Time.current) }
  scope :active, -> { where('valid_until > ? OR valid_until = ?', Time.current, 'infinity'::timestamptz) }
  scope :pending_approval, -> { where(approval_required: true, approval_status: 'pending') }
  scope :approved, -> { where(approval_status: 'approved') }
  scope :recent, -> { order(created_at: :desc) }

  # Get current attributes for a tuple
  def self.current_for(tuple_id, tenant_id: 'default')
    for_tenant(tenant_id)
      .for_tuple(tuple_id)
      .current
      .first
  end

  # Get attributes at a specific point in time
  def self.at_time(tuple_id, timestamp, tenant_id: 'default')
    for_tenant(tenant_id)
      .for_tuple(tuple_id)
      .valid_at(timestamp)
      .first
  end

  # Create a new version using the stored function
  def self.create_version!(
    tuple_id:,
    metadata: {},
    tenant_id: 'default',
    created_by: nil,
    change_reason: nil,
    usage_count: nil,
    max_usage: nil,
    granted_by: nil,
    approval_required: nil,
    approval_status: nil
  )
    result = connection.execute(<<~SQL)
      SELECT create_rel_tuple_attribute_version(
        #{connection.quote(tuple_id)},
        #{connection.quote(metadata.to_json)},
        #{connection.quote(created_by)},
        #{connection.quote(change_reason)},
        #{connection.quote(tenant_id)},
        #{usage_count || 'NULL'},
        #{max_usage || 'NULL'},
        #{connection.quote(granted_by)},
        #{approval_required.nil? ? 'NULL' : approval_required},
        #{connection.quote(approval_status)}
      ) as id
    SQL

    version_id = result.first['id']

    # Invalidate cache for this relationship
    AttributeCache.invalidate_rel(tuple_id, tenant_id: tenant_id)

    find(version_id)
  end

  # Check if this is the current version
  def current?
    is_current || valid_until == Float::INFINITY || valid_until.to_s == 'Infinity'
  end

  # Check if expired
  def expired?
    valid_until && valid_until < Time.current
  end

  # Check if usage limit reached
  def usage_limit_reached?
    max_usage && usage_count >= max_usage
  end

  # Increment usage counter
  def increment_usage!
    update!(usage_count: usage_count + 1)
  end

  # Check if approval is needed
  def needs_approval?
    approval_required && approval_status != 'approved'
  end

  # Approve access
  def approve!(approver:, reason: nil)
    update!(
      approval_status: 'approved',
      metadata: metadata.merge(
        'approved_by' => approver,
        'approved_at' => Time.current.iso8601,
        'approval_reason' => reason
      ).compact
    )
  end

  # Deny access
  def deny!(denier:, reason: nil)
    update!(
      approval_status: 'denied',
      metadata: metadata.merge(
        'denied_by' => denier,
        'denied_at' => Time.current.iso8601,
        'denial_reason' => reason
      ).compact
    )
  end

  private

  def invalidate_cache
    AttributeCache.invalidate_rel(tuple_id, tenant_id: tenant_id)
  end
end
