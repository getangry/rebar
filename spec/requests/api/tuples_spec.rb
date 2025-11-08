# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/tuples', type: :request do
  path '/api/tuples' do
    post 'Create a relationship tuple' do
      tags 'Relationship Tuples'
      description 'Create a new relationship between a subject and an actor'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          subject: { type: :string, example: 'document', description: 'Subject type' },
          id: { type: :string, example: '1', description: 'Subject ID' },
          relation: { type: :string, example: 'viewer', description: 'Relation type' },
          actor: { type: :string, example: 'user', description: 'Actor type' },
          actor_id: { type: :string, example: 'alice', description: 'Actor ID' },
          actor_rel: { type: :string, example: 'member', description: 'Actor relation (optional)', nullable: true }
        },
        required: ['subject', 'id', 'relation', 'actor', 'actor_id']
      }

      response '201', 'tuple created' do
        schema type: :object,
               properties: {
                 ok: { type: :boolean }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:body) do
          {
            subject: 'document',
            id: '1',
            relation: 'viewer',
            actor: 'user',
            actor_id: 'alice'
          }
        end

        run_test!
      end

      response '422', 'invalid tuple' do
        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:body) { { subject: 'document' } }

        run_test!
      end
    end

    delete 'Delete a relationship tuple' do
      tags 'Relationship Tuples'
      description 'Remove an existing relationship'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          subject: { type: :string },
          id: { type: :string },
          relation: { type: :string },
          actor: { type: :string },
          actor_id: { type: :string }
        },
        required: ['subject', 'id', 'relation', 'actor', 'actor_id']
      }

      response '200', 'tuple deleted' do
        schema type: :object,
               properties: {
                 ok: { type: :boolean }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:body) do
          {
            subject: 'document',
            id: '1',
            relation: 'viewer',
            actor: 'user',
            actor_id: 'alice'
          }
        end

        run_test!
      end
    end
  end

  path '/api/tuples/batch' do
    post 'Create multiple relationship tuples' do
      tags 'Relationship Tuples'
      description 'Create multiple relationships in a single request'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tuples: {
            type: :array,
            items: {
              type: :object,
              properties: {
                subject: { type: :string },
                id: { type: :string },
                relation: { type: :string },
                actor: { type: :string },
                actor_id: { type: :string },
                actor_rel: { type: :string, nullable: true }
              }
            }
          }
        },
        required: ['tuples']
      }

      response '201', 'tuples created' do
        schema type: :object,
               properties: {
                 ok: { type: :boolean },
                 count: { type: :integer }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:body) do
          {
            tuples: [
              {
                subject: 'document',
                id: '1',
                relation: 'viewer',
                actor: 'user',
                actor_id: 'alice'
              }
            ]
          }
        end

        run_test!
      end
    end

    delete 'Delete multiple relationship tuples' do
      tags 'Relationship Tuples'
      description 'Remove multiple relationships in a single request'
      consumes 'application/json'
      produces 'application/json'

      parameter name: 'X-Service-Id', in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tuples: {
            type: :array,
            items: {
              type: :object,
              properties: {
                subject: { type: :string },
                id: { type: :string },
                relation: { type: :string },
                actor: { type: :string },
                actor_id: { type: :string }
              }
            }
          }
        },
        required: ['tuples']
      }

      response '200', 'tuples deleted' do
        schema type: :object,
               properties: {
                 ok: { type: :boolean },
                 count: { type: :integer }
               }

        let(:'X-Service-Id') { 'dev' }
        let(:body) do
          {
            tuples: [
              {
                subject: 'document',
                id: '1',
                relation: 'viewer',
                actor: 'user',
                actor_id: 'alice'
              }
            ]
          }
        end

        run_test!
      end
    end
  end
end
