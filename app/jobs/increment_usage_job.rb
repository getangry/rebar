class IncrementUsageJob < ApplicationJob
  queue_as :default

  def perform(rel_attr_id)
    rel_attr = RelTupleAttribute.find_by(id: rel_attr_id)
    return unless rel_attr

    rel_attr.increment_usage!

    # Invalidate cache
    AttributeCache.invalidate_rel(rel_attr.tuple_id, tenant_id: rel_attr.tenant_id)
  rescue StandardError => e
    Rails.logger.error("Failed to increment usage for #{rel_attr_id}: #{e.message}")
  end
end
