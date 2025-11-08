class AnalyticsEvent < ApplicationRecord
  # Associations
  belongs_to :service, optional: true
  belongs_to :api_key, optional: true

  # Validations
  validates :event_type, presence: true
  validates :tenant_id, presence: true

  # Scopes
  scope :for_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
  scope :for_service, ->(service_id) { where(service_id: service_id) }
  scope :for_api_key, ->(api_key_id) { where(api_key_id: api_key_id) }
  scope :permission_checks, -> { where(event_type: ['check', 'explain']) }
  scope :allowed, -> { where(allowed: true) }
  scope :denied, -> { where(allowed: false) }
  scope :since, ->(time) { where('created_at >= ?', time) }
  scope :recent, -> { order(created_at: :desc) }

  # Event types
  EVENT_TYPES = %w[check explain create_tuple delete_tuple list_tuples].freeze
end
