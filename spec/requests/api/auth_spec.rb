# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/auth', type: :request do
  path '/api/auth/check' do
    post 'Check if a permission is granted' do
      tags 'Authorization'
      description 'Check if an actor has a specific permission on a subject'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer token (format: Bearer <api_key>)'
      parameter name: 'X-Tenant', in: :header, type: :string, required: false,
                description: 'Tenant identifier (defaults to "default")'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          actor: { type: :string, example: 'user' },
          actor_id: { type: :string, example: 'alice' },
          permission: { type: :string, example: 'view' },
          subject: { type: :string, example: 'document' },
          subject_id: { type: :string, example: '1' }
        },
        required: ['actor', 'actor_id', 'permission', 'subject', 'subject_id']
      }

      response '200', 'permission check result' do
        schema type: :object,
               properties: {
                 allow: { type: :boolean }
               },
               required: ['allow']

        let(:Authorization) { 'Bearer dev' }
        let(:'X-Tenant') { 'default' }
        let(:body) do
          {
            actor: 'user',
            actor_id: 'alice',
            permission: 'view',
            subject: 'document',
            subject_id: '1'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to have_key('allow')
          expect(data['allow']).to be_in([true, false])
        end
      end

      response '422', 'invalid request' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { 'Bearer dev' }
        let(:body) { { actor: 'user' } }

        run_test!
      end
    end

    post 'Check permission using tuple format' do
      tags 'Authorization'
      description 'Check permission using Zanzibar-style tuple format (subject:id#relation@actor:id)'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tuple: {
            type: :string,
            example: 'document:1#view@user:alice',
            description: 'Zanzibar tuple format: subject_type:subject_id#relation@actor_type:actor_id'
          }
        },
        required: ['tuple']
      }

      response '200', 'permission check result' do
        schema type: :object,
               properties: {
                 allow: { type: :boolean }
               }

        let(:Authorization) { 'Bearer dev' }
        let(:'X-Tenant') { 'default' }
        let(:body) { { tuple: 'document:1#view@user:alice' } }

        run_test!
      end

      response '422', 'invalid tuple format' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:Authorization) { 'Bearer dev' }
        let(:body) { { tuple: 'invalid' } }

        run_test!
      end
    end
  end

  path '/api/auth/explain' do
    post 'Explain why a permission is granted or denied' do
      tags 'Authorization'
      description 'Explain the authorization decision path for debugging'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          actor: { type: :string, example: 'user' },
          actor_id: { type: :string, example: 'alice' },
          permission: { type: :string, example: 'view' },
          subject: { type: :string, example: 'document' },
          subject_id: { type: :string, example: '1' }
        },
        required: ['actor', 'actor_id', 'permission', 'subject', 'subject_id']
      }

      response '200', 'explanation of authorization decision' do
        schema type: :object,
               properties: {
                 allow: { type: :boolean },
                 path: {
                   type: :array,
                   items: { type: :object }
                 }
               },
               required: ['allow']

        let(:Authorization) { 'Bearer dev' }
        let(:'X-Tenant') { 'default' }
        let(:body) do
          {
            actor: 'user',
            actor_id: 'alice',
            permission: 'view',
            subject: 'document',
            subject_id: '1'
          }
        end

        run_test!
      end
    end

    post 'Explain permission using tuple format' do
      tags 'Authorization'
      description 'Explain permission decision using Zanzibar-style tuple format (subject:id#relation@actor:id)'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tuple: {
            type: :string,
            example: 'document:1#view@user:alice',
            description: 'Zanzibar tuple format: subject_type:subject_id#relation@actor_type:actor_id'
          }
        },
        required: ['tuple']
      }

      response '200', 'explanation of authorization decision' do
        schema type: :object,
               properties: {
                 allow: { type: :boolean },
                 path: { type: :array, items: { type: :object } }
               }

        let(:Authorization) { 'Bearer dev' }
        let(:'X-Tenant') { 'default' }
        let(:body) { { tuple: 'document:1#view@user:alice' } }

        run_test!
      end
    end
  end
end
