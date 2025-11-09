module Api
  class AttributesController < ::ApplicationController
    include ServiceAuth

    # Allow attribute reads without authentication for development
    # In production, you may want to enable authentication
    skip_before_action :authenticate_service!, only: [:show, :index, :history, :schemas]

    # GET /api/attributes/:entity_type/:subject_id
    # Get current attributes for an entity
    def show
      entity_type = params[:entity_type]
      subject_id = params[:subject_id]

      attrs = AttributeVersion.current_for(entity_type, subject_id, tenant_id: tenant)

      if attrs
        render json: format_attribute_version(attrs)
      else
        render json: { error: 'Attributes not found' }, status: :not_found
      end
    end

    # GET /api/attributes/:entity_type/:subject_id/history
    # Get version history for an entity
    def history
      entity_type = params[:entity_type]
      subject_id = params[:subject_id]

      versions = AttributeVersion.history_for(entity_type, subject_id, tenant_id: tenant)

      render json: {
        subject: entity_type,
        subject_id: subject_id,
        versions: versions.map { |v| format_attribute_version(v) }
      }
    end

    # POST /api/attributes
    # Create or update attributes for an entity
    def create
      entity_type = params[:entity_type]
      subject_id = params[:subject_id]
      metadata = params[:metadata] || {}

      # Hot attributes (indexed columns)
      max_requests = params[:max_requests]
      current_requests = params[:current_requests]
      risk_level = params[:risk_level]
      requires_mfa = params[:requires_mfa]

      version = AttributeVersion.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        metadata: metadata,
        tenant_id: tenant,
        created_by: current_user_id,
        change_reason: params[:change_reason],
        max_requests: max_requests,
        current_requests: current_requests,
        risk_level: risk_level,
        requires_mfa: requires_mfa
      )

      # Invalidate cache
      AttributeCache.invalidate_entity(entity_type, subject_id, tenant_id: tenant)

      render json: format_attribute_version(version), status: :created
    rescue AttributeSchema::ValidationError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # DELETE /api/attributes/:entity_type/:subject_id
    # Close current version (set valid_until to now)
    def destroy
      entity_type = params[:entity_type]
      subject_id = params[:subject_id]

      current_version = AttributeVersion.current_for(entity_type, subject_id, tenant_id: tenant)

      unless current_version
        return render json: { error: 'No current version found' }, status: :not_found
      end

      current_version.update!(valid_until: Time.current)

      # Invalidate cache
      AttributeCache.invalidate_entity(entity_type, subject_id, tenant_id: tenant)

      render json: { message: 'Attributes removed' }
    end

    # GET /api/attributes/schemas
    # List all attribute schemas
    def schemas
      schemas = AttributeSchema.active.group_by(&:entity_type)

      render json: {
        schemas: schemas.transform_values do |versions|
          versions.map { |v| format_schema(v) }
        end
      }
    end

    # POST /api/attributes/schemas
    # Create or update an attribute schema
    def create_schema
      entity_type = params[:entity_type]
      schema = params[:schema]
      description = params[:description]

      version = AttributeSchema.latest_version_for(entity_type) + 1

      # Deactivate previous version
      AttributeSchema.where(entity_type: entity_type, active: true).update_all(active: false)

      # Create new version
      schema_record = AttributeSchema.create!(
        entity_type: entity_type,
        version: version,
        schema: schema,
        description: description,
        created_by: current_user_id
      )

      render json: format_schema(schema_record), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    # Relationship Attributes

    # GET /api/attributes/relationships/:tuple_id
    # Get current attributes for a relationship
    def show_relationship
      tuple_id = params[:tuple_id]

      attrs = RelTupleAttribute.current_for(tuple_id, tenant_id: tenant)

      if attrs
        render json: format_rel_attribute(attrs)
      else
        render json: { error: 'Relationship attributes not found' }, status: :not_found
      end
    end

    # POST /api/attributes/relationships
    # Create or update attributes for a relationship
    def create_relationship
      tuple_id = params[:tuple_id]
      metadata = params[:metadata] || {}

      # Verify tuple exists
      tuple = RelTuple.find_by(id: tuple_id, tenant_id: tenant)
      unless tuple
        return render json: { error: 'Tuple not found' }, status: :not_found
      end

      # Hot attributes
      usage_count = params[:usage_count]
      max_usage = params[:max_usage]
      granted_by = params[:granted_by]
      approval_required = params[:approval_required]
      approval_status = params[:approval_status]

      version = RelTupleAttribute.create_version!(
        tuple_id: tuple_id,
        metadata: metadata,
        tenant_id: tenant,
        created_by: current_user_id,
        change_reason: params[:change_reason],
        usage_count: usage_count,
        max_usage: max_usage,
        granted_by: granted_by,
        approval_required: approval_required,
        approval_status: approval_status
      )

      # Invalidate cache
      AttributeCache.invalidate_rel(tuple_id, tenant_id: tenant)

      render json: format_rel_attribute(version), status: :created
    end

    private

    def tenant
      request.headers['X-Tenant'] || 'default'
    end

    def current_user_id
      # Use authenticated service ID (verified by ServiceAuth concern)
      return 'system' unless current_service
      "service:#{current_service[:id]}"
    end

    def format_attribute_version(version)
      {
        id: version.id,
        entity_type: version.entity_type,
        subject_id: version.subject_id,
        metadata: version.metadata,
        max_requests: version.max_requests,
        current_requests: version.current_requests,
        risk_level: version.risk_level,
        requires_mfa: version.requires_mfa,
        valid_from: version.valid_from,
        valid_until: version.valid_until,
        version_number: version.version_number,
        created_by: version.created_by,
        change_reason: version.change_reason,
        created_at: version.created_at
      }
    end

    def format_rel_attribute(attr)
      {
        id: attr.id,
        tuple_id: attr.tuple_id,
        metadata: attr.metadata,
        usage_count: attr.usage_count,
        max_usage: attr.max_usage,
        granted_by: attr.granted_by,
        approval_required: attr.approval_required,
        approval_status: attr.approval_status,
        valid_from: attr.valid_from,
        valid_until: attr.valid_until,
        version_number: attr.version_number,
        created_by: attr.created_by,
        created_at: attr.created_at
      }
    end

    def format_schema(schema)
      {
        id: schema.id,
        entity_type: schema.entity_type,
        version: schema.version,
        schema: schema.schema,
        description: schema.description,
        active: schema.active,
        created_by: schema.created_by,
        created_at: schema.created_at
      }
    end
  end
end
