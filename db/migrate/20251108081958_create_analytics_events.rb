class CreateAnalyticsEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :analytics_events, id: :uuid do |t|
      # Who made the request
      t.string :tenant_id, null: false, default: 'default'
      t.uuid :service_id
      t.uuid :api_key_id
      t.string :ip_address

      # What was requested
      t.string :event_type, null: false # 'check', 'explain', 'create_tuple', 'delete_tuple', etc.
      t.string :actor
      t.string :actor_id
      t.string :permission
      t.string :subject
      t.string :subject_id

      # Result
      t.boolean :allowed # true/false for permission checks, null for other events
      t.integer :latency_ms # how long the operation took
      t.string :endpoint # API endpoint that was hit

      # Additional context
      t.jsonb :metadata, default: {}

      t.timestamp :created_at, null: false # Use timestamp for time-series data
    end

    # Indexes for efficient querying
    add_index :analytics_events, [:tenant_id, :created_at], name: 'idx_analytics_tenant_time'
    add_index :analytics_events, [:service_id, :created_at], name: 'idx_analytics_service_time'
    add_index :analytics_events, [:api_key_id, :created_at], name: 'idx_analytics_apikey_time'
    add_index :analytics_events, [:event_type, :created_at], name: 'idx_analytics_event_time'
    add_index :analytics_events, [:tenant_id, :event_type, :allowed], name: 'idx_analytics_checks'
    add_index :analytics_events, [:subject, :permission], name: 'idx_analytics_permission'
  end
end
