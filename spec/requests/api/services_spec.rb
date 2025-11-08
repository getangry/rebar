# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/services', type: :request do
  path '/api/services' do
    get 'List all services' do
      tags 'Services'
      description 'Get all services for the current tenant'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'services listed' do
        schema type: :object,
               properties: {
                 services: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       name: { type: :string },
                       description: { type: :string, nullable: true },
                       schema_name: { type: :string },
                       active: { type: :boolean },
                       tenant_id: { type: :string },
                       allowed_subjects: { type: :array, items: { type: :string } },
                       allowed_relations: { type: :array, items: { type: :string } },
                       metadata: { type: :object },
                       created_at: { type: :string, format: :datetime },
                       updated_at: { type: :string, format: :datetime }
                     }
                   }
                 }
               }

        let(:'X-Service-Id') { 'dev' }
        run_test!
      end
    end

    post 'Create a new service' do
      tags 'Services'
      description 'Register a new service with API key generation'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          service: {
            type: :object,
            properties: {
              name: { type: :string, example: 'My Service' },
              description: { type: :string, example: 'Service description' },
              schema_name: { type: :string, example: 'default' },
              active: { type: :boolean, example: true },
              allowed_subjects: { type: :array, items: { type: :string }, example: ['document', 'folder'] },
              allowed_relations: { type: :array, items: { type: :string }, example: ['viewer', 'editor'] },
              metadata: { type: :object, example: {} }
            },
            required: ['name']
          }
        }
      }

      response '201', 'service created' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 name: { type: :string },
                 api_key: { type: :string, description: 'Only returned on creation/regeneration' },
                 schema_name: { type: :string },
                 active: { type: :boolean }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:body) do
          {
            service: {
              name: 'Test Service',
              description: 'A test service',
              schema_name: 'default'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid service data' do
        schema type: :object,
               properties: {
                 error: { type: :string },
                 errors: { type: :array, items: { type: :string } }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:body) { { service: {} } }

        run_test!
      end
    end
  end

  path '/api/services/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Service ID'

    get 'Get a specific service' do
      tags 'Services'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'service found' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 name: { type: :string },
                 description: { type: :string, nullable: true },
                 schema_name: { type: :string },
                 active: { type: :boolean },
                 allowed_subjects: { type: :array },
                 allowed_relations: { type: :array },
                 metadata: { type: :object }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:id) { 1 }

        run_test!
      end

      response '404', 'service not found' do
        let(:'X-Service-Id') { 'dev' }
        let(:id) { 999999 }

        run_test!
      end
    end

    patch 'Update a service' do
      tags 'Services'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          service: {
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string },
              active: { type: :boolean },
              metadata: { type: :object }
            }
          }
        }
      }

      response '200', 'service updated' do
        let(:'X-Service-Id') { 'dev' }
        let(:id) { 1 }
        let(:body) { { service: { name: 'Updated Name' } } }

        run_test!
      end
    end

    delete 'Delete a service' do
      tags 'Services'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '204', 'service deleted' do
        let(:'X-Service-Id') { 'dev' }
        let(:id) { 1 }

        run_test!
      end
    end
  end

  path '/api/services/{id}/regenerate_key' do
    parameter name: :id, in: :path, type: :integer, description: 'Service ID'

    post 'Regenerate service API key' do
      tags 'Services'
      description 'Generate a new API key for the service (invalidates old key)'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'key regenerated' do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 api_key: { type: :string },
                 service: { type: :object }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:id) { 1 }

        run_test!
      end
    end
  end

  path '/api/services/{id}/activate' do
    parameter name: :id, in: :path, type: :integer, description: 'Service ID'

    post 'Activate a service' do
      tags 'Services'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'service activated' do
        let(:'X-Service-Id') { 'dev' }
        let(:id) { 1 }

        run_test!
      end
    end
  end

  path '/api/services/{id}/deactivate' do
    parameter name: :id, in: :path, type: :integer, description: 'Service ID'

    post 'Deactivate a service' do
      tags 'Services'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'service deactivated' do
        let(:'X-Service-Id') { 'dev' }
        let(:id) { 1 }

        run_test!
      end
    end
  end
end
