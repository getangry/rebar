module Api
  class SchemasController < ::ApplicationController
    include ServiceAuth

    # GET /api/schemas
    # List all available schemas
    def index
      schema_index = Rails.root.join("schemas/index.rb")
      load schema_index

      schemas = AuthSchema.list_schemas.map do |schema_name|
        AuthSchema.schema_info(schema_name)
      end

      render json: { schemas: schemas }
    end

    # GET /api/schemas/:name
    # Get details for a specific schema
    def show
      schema_index = Rails.root.join("schemas/index.rb")
      load schema_index

      schema_name = params[:name]
      schema = AuthSchema.get_schema(schema_name)

      if schema
        render json: AuthSchema.schema_info(schema_name)
      else
        render json: { error: "Schema '#{schema_name}' not found" }, status: :not_found
      end
    end
  end
end
