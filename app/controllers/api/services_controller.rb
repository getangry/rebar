module Api
  class ServicesController < ::ApplicationController
    include ServiceAuth

    before_action :set_service, only: [:show, :update, :destroy, :regenerate_key, :activate, :deactivate, :add_subject, :remove_subject, :add_relation, :remove_relation]

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
    # Regenerate API key
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
        :schema_name,
        :active,
        allowed_subjects: [],
        allowed_relations: [],
        metadata: {}
      )
    end

    def service_update_params
      params.require(:service).permit(
        :name,
        :description,
        :schema_name,
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
        schema_name: service.schema_name,
        active: service.active,
        tenant_id: service.tenant_id,
        allowed_subjects: service.allowed_subjects,
        allowed_relations: service.allowed_relations,
        metadata: service.metadata,
        created_at: service.created_at,
        updated_at: service.updated_at
      }

      # Only include the plain API key during creation
      result[:api_key] = service.api_key if include_key && service.api_key.present?

      result
    end
  end
end
