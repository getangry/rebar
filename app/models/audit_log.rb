class AuditLog < ApplicationRecord
  # Validations
  validates :tenant_id, presence: true
  validates :service_id, presence: true
  validates :action, presence: true, inclusion: { in: %w[create delete update] }
  validates :resource_type, presence: true

  # Scopes for common queries
  scope :for_tenant, ->(tenant_id) { where(tenant_id: tenant_id) }
  scope :for_service, ->(service_id) { where(service_id: service_id) }
  scope :for_action, ->(action) { where(action: action) }
  scope :for_resource, ->(subject, object_id) { where(subject: subject, object_id: object_id) }
  scope :for_relation, ->(relation) { where(relation: relation) }
  scope :for_actor, ->(actor, actor_id) { where(actor: actor, actor_id: actor_id) }
  scope :recent, -> { order(created_at: :desc) }
  scope :since, ->(time) { where("created_at >= ?", time) }

  # Helper method to format the log entry
  def to_summary
    parts = [
      "#{action.upcase}",
      "#{subject}:#{object_id}",
      "#{relation}",
      "by #{actor}:#{actor_id}"
    ]
    parts << "(reason: #{reason})" if reason.present?
    parts.join(" ")
  end

  # Get all changes for a specific tuple
  def self.tuple_history(tenant_id:, subject:, object_id:, relation:, actor:, actor_id:)
    where(
      tenant_id: tenant_id,
      subject: subject,
      object_id: object_id,
      relation: relation,
      actor: actor,
      actor_id: actor_id
    ).recent
  end
end
