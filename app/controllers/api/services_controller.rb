module Api
  class ServicesController < ::ApplicationController
    include ServiceAuth

    # Skip authentication for service management endpoints (bootstrap use case)
    skip_before_action :authenticate_service!, only: [:index, :create]

    before_action :set_service, only: [:show, :update, :destroy, :regenerate_key, :activate, :deactivate, :add_subject, :remove_subject, :add_relation, :remove_relation, :add_schema, :remove_schema, :create_api_key, :revoke_api_key]

    # GET /api/services
    # List all services for tenant
    def index
      services = Service.for_tenant(tenant).order(created_at: :desc)

      render json: {
        services: services.map { |s| format_service(s, include_key: false) }
      }
    end

    # GET /api/services/:id
    # Get service details
    def show
      render json: format_service(@service, include_key: false)
    end

    # POST /api/services
    # Create a new service
    def create
      service = Service.new(service_params.merge(tenant_id: tenant))

      if service.save
        # Return the plain API key only once during creation
        render json: format_service(service, include_key: true), status: :created
      else
        render json: { error: 'Failed to create service', errors: service.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /api/services/:id
    # Update service
    def update
      if @service.update(service_update_params)
        render json: format_service(@service, include_key: false)
      else
        render json: { error: 'Failed to update service', errors: @service.errors.full_messages }, status: :unprocessable_entity
      end
    end

    # DELETE /api/services/:id
    # Delete service
    def destroy
      @service.destroy
      head :no_content
    end

    # POST /api/services/:id/regenerate_key
    # Regenerate API key (deprecated - use create_api_key instead)
    def regenerate_key
      new_key = @service.regenerate_api_key!
      render json: {
        message: 'API key regenerated successfully',
        api_key: new_key,
        service: format_service(@service, include_key: false)
      }
    rescue => e
      render json: { error: 'Failed to regenerate API key', message: e.message }, status: :unprocessable_entity
    end

    # POST /api/services/:id/api_keys
    # Create a new API key for the service
    def create_api_key
      name = params[:name] || "API Key #{@service.api_keys.count + 1}"
      new_key = @service.create_api_key(name: name)

      render json: {
        message: 'API key created successfully',
        api_key: new_key,
        service: format_service(@service, include_key: false)
      }
    rescue => e
      render json: { error: 'Failed to create API key', message: e.message }, status: :unprocessable_entity
    end

    # DELETE /api/services/:id/api_keys/:api_key_id
    # Revoke an API key
    def revoke_api_key
      api_key = @service.api_keys.find(params[:api_key_id])
      api_key.revoke!

      render json: {
        message: 'API key revoked successfully',
        service: format_service(@service, include_key: false)
      }
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'API key not found' }, status: :not_found
    rescue => e
      render json: { error: 'Failed to revoke API key', message: e.message }, status: :unprocessable_entity
    end

    # POST /api/services/:id/activate
    # Activate service
    def activate
      @service.activate!
      render json: format_service(@service, include_key: false)
    end

    # POST /api/services/:id/deactivate
    # Deactivate service
    def deactivate
      @service.deactivate!
      render json: format_service(@service, include_key: false)
    end

    # POST /api/services/:id/subjects
    # Add allowed subject
    def add_subject
      subject = params.require(:subject)
      @service.add_allowed_subject(subject)
      render json: format_service(@service, include_key: false)
    end

    # DELETE /api/services/:id/subjects/:subject
    # Remove allowed subject
    def remove_subject
      subject = params.require(:subject)
      @service.remove_allowed_subject(subject)
      render json: format_service(@service, include_key: false)
    end

    # POST /api/services/:id/relations
    # Add allowed relation
    def add_relation
      relation = params.require(:relation)
      @service.add_allowed_relation(relation)
      render json: format_service(@service, include_key: false)
    end

    # DELETE /api/services/:id/relations/:relation
    # Remove allowed relation
    def remove_relation
      relation = params.require(:relation)
      @service.remove_allowed_relation(relation)
      render json: format_service(@service, include_key: false)
    end

    # POST /api/services/:id/schemas
    # Add schema
    def add_schema
      schema = params.require(:schema)
      @service.add_schema(schema)
      render json: format_service(@service, include_key: false)
    end

    # DELETE /api/services/:id/schemas/:schema
    # Remove schema
    def remove_schema
      schema = params.require(:schema)
      if @service.remove_schema(schema)
        render json: format_service(@service, include_key: false)
      else
        render json: { error: 'Cannot remove last schema. Service must have at least one schema.' }, status: :unprocessable_entity
      end
    end

    private

    def set_service
      @service = Service.for_tenant(tenant).find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Service not found' }, status: :not_found
    end

    def tenant
      request.headers["X-Tenant"] || "default"
    end

    def service_params
      params.require(:service).permit(
        :name,
        :description,
        :active,
        schemas: [],
        allowed_subjects: [],
        allowed_relations: [],
        metadata: {}
      )
    end

    def service_update_params
      params.require(:service).permit(
        :name,
        :description,
        schemas: [],
        allowed_subjects: [],
        allowed_relations: [],
        metadata: {}
      )
    end

    def format_service(service, include_key: false)
      result = {
        id: service.id,
        name: service.name,
        description: service.description,
        schemas: service.schemas,
        active: service.active,
        tenant_id: service.tenant_id,
        allowed_subjects: service.allowed_subjects,
        allowed_relations: service.allowed_relations,
        metadata: service.metadata,
        created_at: service.created_at,
        updated_at: service.updated_at,
        api_keys: service.api_keys.map { |k| format_api_key(k) }
      }

      # Only include the plain API key during creation
      result[:api_key] = service.api_key if include_key && service.api_key.present?

      result
    end

    def format_api_key(api_key)
      {
        id: api_key.id,
        name: api_key.name,
        key_prefix: api_key.key_prefix,
        active: api_key.active,
        last_used_at: api_key.last_used_at,
        usage_count: api_key.usage_count,
        created_at: api_key.created_at
      }
    end
  end
end
