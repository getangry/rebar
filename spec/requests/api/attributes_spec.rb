# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'api/attributes', type: :request do
  let(:tenant_id) { 'default' }
  let(:authorization) { 'Bearer dev' }

  path '/api/attributes' do
    post 'Create or update entity attributes' do
      tags 'Attributes'
      description 'Set attributes for an entity (creates new version)'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for authentication'
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          entity_type: { type: :string, example: 'document' },
          subject_id: { type: :string, example: 'doc-123' },
          metadata: {
            type: :object,
            example: { classification: 'confidential' }
          },
          requires_mfa: { type: :boolean, example: true },
          risk_level: { type: :string, enum: ['low', 'medium', 'high'], example: 'high' },
          max_requests: { type: :integer, example: 1000 },
          change_reason: { type: :string, example: 'Security policy update' }
        },
        required: ['entity_type', 'subject_id']
      }

      response '201', 'attributes created' do
        let(:Authorization) { authorization }
        let(:body) do
          {
            entity_type: 'document',
            subject_id: 'doc-123',
            requires_mfa: true,
            metadata: { classification: 'confidential' }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['entity_type']).to eq('document')
          expect(data['subject_id']).to eq('doc-123')
          expect(data['requires_mfa']).to be true
          expect(data['metadata']['classification']).to eq('confidential')
        end
      end

      response '422', 'validation error' do
        let(:Authorization) { authorization }
        let(:body) { { entity_type: 'document' } } # Missing subject_id

        run_test!
      end
    end
  end

  path '/api/attributes/{entity_type}/{subject_id}' do
    parameter name: :entity_type, in: :path, type: :string
    parameter name: :subject_id, in: :path, type: :string

    get 'Get current attributes for an entity' do
      tags 'Attributes'
      produces 'application/json'

      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'current attributes' do
        let(:entity_type) { 'document' }
        let(:subject_id) { 'doc-123' }

        before do
          AttributeVersion.create_version!(
            entity_type: entity_type,
            subject: entity_type,
            subject_id: subject_id,
            tenant_id: tenant_id,
            requires_mfa: true,
            metadata: { 'level' => 'high' }
          )
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['entity_type']).to eq('document')
          expect(data['subject_id']).to eq('doc-123')
          expect(data['requires_mfa']).to be true
          expect(data['metadata']['level']).to eq('high')
        end
      end

      response '404', 'attributes not found' do
        let(:entity_type) { 'document' }
        let(:subject_id) { 'nonexistent' }

        run_test!
      end
    end

    delete 'Remove current attributes' do
      tags 'Attributes'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'attributes removed' do
        let(:Authorization) { authorization }
        let(:entity_type) { 'document' }
        let(:subject_id) { 'doc-123' }

        before do
          AttributeVersion.create_version!(
            entity_type: entity_type,
            subject: entity_type,
            subject_id: subject_id,
            tenant_id: tenant_id,
            metadata: {}
          )
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to include('removed')

          # Verify attributes were closed
          current = AttributeVersion.current_for(entity_type, subject_id, tenant_id: tenant_id)
          expect(current).to be_nil
        end
      end

      response '404', 'no current version found' do
        let(:Authorization) { authorization }
        let(:entity_type) { 'document' }
        let(:subject_id) { 'nonexistent' }

        run_test!
      end
    end
  end

  path '/api/attributes/{entity_type}/{subject_id}/history' do
    parameter name: :entity_type, in: :path, type: :string
    parameter name: :subject_id, in: :path, type: :string

    get 'Get attribute version history' do
      tags 'Attributes'
      description 'Get all attribute versions for an entity'
      produces 'application/json'

      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'version history' do
        let(:entity_type) { 'document' }
        let(:subject_id) { 'doc-123' }

        before do
          3.times do |i|
            AttributeVersion.create_version!(
              entity_type: entity_type,
              subject: entity_type,
              subject_id: subject_id,
              tenant_id: tenant_id,
              metadata: { 'version' => i.to_s },
              change_reason: "Update #{i}"
            )
          end
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['subject']).to eq('document')
          expect(data['subject_id']).to eq('doc-123')
          expect(data['versions'].size).to eq(3)
          expect(data['versions'].first['version_number']).to eq(3)
          expect(data['versions'].first['metadata']['version']).to eq('2')
        end
      end
    end
  end

  path '/api/attributes/relationships' do
    post 'Create or update relationship attributes' do
      tags 'Attributes'
      description 'Set attributes for a relationship tuple'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tuple_id: { type: :string, format: :uuid },
          metadata: { type: :object },
          max_usage: { type: :integer, example: 100 },
          usage_count: { type: :integer, example: 0 },
          granted_by: { type: :string, example: 'user:admin' },
          approval_required: { type: :boolean, example: true },
          approval_status: { type: :string, enum: ['pending', 'approved', 'denied'] },
          change_reason: { type: :string }
        },
        required: ['tuple_id']
      }

      response '201', 'relationship attributes created' do
        let(:Authorization) { authorization }
        let(:tuple) do
          RelTuple.create!(
            tenant_id: tenant_id,
            actor: 'user',
            actor_id: 'alice',
            relation: 'viewer',
            subject: 'document',
            subject_id: 'doc-123'
          )
        end
        let(:body) do
          {
            tuple_id: tuple.id,
            max_usage: 100,
            usage_count: 0,
            granted_by: 'user:manager'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tuple_id']).to eq(tuple.id)
          expect(data['max_usage']).to eq(100)
          expect(data['granted_by']).to eq('user:manager')
        end
      end

      response '404', 'tuple not found' do
        let(:Authorization) { authorization }
        let(:body) do
          {
            tuple_id: SecureRandom.uuid,
            metadata: {}
          }
        end

        run_test!
      end
    end
  end

  path '/api/attributes/relationships/{tuple_id}' do
    parameter name: :tuple_id, in: :path, type: :string, format: :uuid

    get 'Get current attributes for a relationship' do
      tags 'Attributes'
      produces 'application/json'

      parameter name: 'X-Tenant', in: :header, type: :string, required: false

      response '200', 'relationship attributes' do
        let(:tuple) do
          RelTuple.create!(
            tenant_id: tenant_id,
            actor: 'user',
            actor_id: 'alice',
            relation: 'viewer',
            subject: 'document',
            subject_id: 'doc-123'
          )
        end
        let(:tuple_id) { tuple.id }

        before do
          RelTupleAttribute.create_version!(
            tuple_id: tuple.id,
            tenant_id: tenant_id,
            max_usage: 50,
            usage_count: 10,
            metadata: {}
          )
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tuple_id']).to eq(tuple.id)
          expect(data['max_usage']).to eq(50)
          expect(data['usage_count']).to eq(10)
        end
      end

      response '404', 'relationship attributes not found' do
        let(:tuple_id) { SecureRandom.uuid }

        run_test!
      end
    end
  end
end
