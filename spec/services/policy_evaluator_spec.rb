# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PolicyEvaluator do
  let(:tenant_id) { 'test-tenant' }
  let(:engine) { double('PermissionEngine') }
  let(:evaluator) { described_class.new(tenant_id: tenant_id, engine: engine) }

  # Clear cache before each test to prevent pollution
  before(:each) do
    AttributeCache.clear_all!
  end

  describe '#check' do
    let(:actor) { 'user' }
    let(:actor_id) { 'alice' }
    let(:permission) { 'viewer' }
    let(:subject) { 'document' }
    let(:subject_id) { '123' }
    let(:context) { {} }

    context 'when no relationship exists' do
      before do
        allow(engine).to receive(:check).and_return(false)
      end

      it 'denies access' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
        expect(result[:allow]).to be false
        expect(result[:reason]).to include('No relationship found')
      end
    end

    context 'when relationship exists but no attributes' do
      let!(:tuple) do
        RelTuple.create!(
          tenant_id: tenant_id,
          actor: actor,
          actor_id: actor_id,
          relation: permission,
          subject: subject,
          subject_id: subject_id
        )
      end

      before do
        allow(engine).to receive(:check).and_return(true)
      end

      it 'allows access' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
        expect(result[:allow]).to be true
      end
    end

    context 'with temporal validity (expiration)' do
      let!(:tuple) do
        RelTuple.create!(
          tenant_id: tenant_id,
          actor: actor,
          actor_id: actor_id,
          relation: permission,
          subject: subject,
          subject_id: subject_id
        )
      end

      let!(:rel_attrs) do
        RelTupleAttribute.create_version!(
          tuple_id: tuple.id,
          tenant_id: tenant_id,
          metadata: { 'expires_at' => 1.hour.from_now.iso8601 }
        )
      end

      before do
        allow(engine).to receive(:check).and_return(true)
      end

      it 'allows access when not expired' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
        expect(result[:allow]).to be true
      end

      it 'denies access when expired' do
        rel_attrs.update!(metadata: { 'expires_at' => 1.hour.ago.iso8601 })
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
        expect(result[:allow]).to be false
        expect(result[:reason]).to include('expired')
      end
    end

    context 'with usage limits' do
      let!(:tuple) do
        RelTuple.create!(
          tenant_id: tenant_id,
          actor: actor,
          actor_id: actor_id,
          relation: permission,
          subject: subject,
          subject_id: subject_id
        )
      end

      let!(:rel_attrs) do
        RelTupleAttribute.create_version!(
          tuple_id: tuple.id,
          tenant_id: tenant_id,
          metadata: {},
          max_usage: 5,
          usage_count: 3
        )
      end

      before do
        allow(engine).to receive(:check).and_return(true)
      end

      it 'allows access when under limit' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
        expect(result[:allow]).to be true
      end

      it 'denies access when limit exceeded' do
        rel_attrs.update!(usage_count: 5)
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
        expect(result[:allow]).to be false
        expect(result[:reason]).to include('Usage limit exceeded')
      end
    end

    context 'with MFA requirement' do
      let!(:tuple) do
        RelTuple.create!(
          tenant_id: tenant_id,
          actor: actor,
          actor_id: actor_id,
          relation: permission,
          subject: subject,
          subject_id: subject_id
        )
      end

      let!(:entity_attrs) do
        AttributeVersion.create_version!(
          entity_type: subject,
          subject: subject,
          subject_id: subject_id,
          tenant_id: tenant_id,
          requires_mfa: true,
          metadata: {}
        )
      end

      before do
        allow(engine).to receive(:check).and_return(true)
      end

      it 'denies access without MFA context' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, {})
        expect(result[:allow]).to be false
        expect(result[:reason]).to include('Multi-factor authentication required')
      end

      it 'allows access with MFA context' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, { mfa_verified: true })
        expect(result[:allow]).to be true
      end
    end

    context 'with IP whitelist' do
      let!(:tuple) do
        RelTuple.create!(
          tenant_id: tenant_id,
          actor: actor,
          actor_id: actor_id,
          relation: permission,
          subject: subject,
          subject_id: subject_id
        )
      end

      let!(:entity_attrs) do
        AttributeVersion.create_version!(
          entity_type: subject,
          subject: subject,
          subject_id: subject_id,
          tenant_id: tenant_id,
          metadata: {
            'allowed_ips' => ['10.0.0.0/8', '192.168.1.0/24']
          }
        )
      end

      before do
        allow(engine).to receive(:check).and_return(true)
      end

      it 'allows access from whitelisted IP' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, { ip_address: '10.0.1.50' })
        expect(result[:allow]).to be true
      end

      it 'denies access from non-whitelisted IP' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, { ip_address: '203.0.113.1' })
        expect(result[:allow]).to be false
        expect(result[:reason]).to include('IP address not in allowed range')
      end
    end

    context 'with approval workflow' do
      let!(:tuple) do
        RelTuple.create!(
          tenant_id: tenant_id,
          actor: actor,
          actor_id: actor_id,
          relation: permission,
          subject: subject,
          subject_id: subject_id
        )
      end

      before do
        allow(engine).to receive(:check).and_return(true)
      end

      context 'when approval pending' do
        let!(:rel_attrs) do
          RelTupleAttribute.create_version!(
            tuple_id: tuple.id,
            tenant_id: tenant_id,
            approval_required: true,
            approval_status: 'pending',
            metadata: { 'ticket_id' => 'JIRA-123' }
          )
        end

        it 'denies access' do
          result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
          expect(result[:allow]).to be false
          expect(result[:reason]).to include('Approval pending')
        end
      end

      context 'when approval denied' do
        let!(:rel_attrs) do
          RelTupleAttribute.create_version!(
            tuple_id: tuple.id,
            tenant_id: tenant_id,
            approval_required: true,
            approval_status: 'denied',
            metadata: {}
          )
        end

        it 'denies access' do
          result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
          expect(result[:allow]).to be false
          expect(result[:reason]).to include('denied by approver')
        end
      end

      context 'when approval approved' do
        let!(:rel_attrs) do
          RelTupleAttribute.create_version!(
            tuple_id: tuple.id,
            tenant_id: tenant_id,
            approval_required: true,
            approval_status: 'approved',
            metadata: {}
          )
        end

        it 'allows access' do
          result = evaluator.check(actor, actor_id, permission, subject, subject_id, context)
          expect(result[:allow]).to be true
        end
      end
    end

    context 'with risk-based access' do
      let!(:tuple) do
        RelTuple.create!(
          tenant_id: tenant_id,
          actor: actor,
          actor_id: actor_id,
          relation: permission,
          subject: subject,
          subject_id: subject_id
        )
      end

      let!(:rel_attrs) do
        RelTupleAttribute.create_version!(
          tuple_id: tuple.id,
          tenant_id: tenant_id,
          metadata: { 'risk_level' => 'high' }
        )
      end

      before do
        allow(engine).to receive(:check).and_return(true)
      end

      it 'denies access without additional verification' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, {})
        expect(result[:allow]).to be false
        expect(result[:reason]).to include('Additional verification required')
      end

      it 'allows access with additional verification' do
        result = evaluator.check(actor, actor_id, permission, subject, subject_id, { additional_verification: true })
        expect(result[:allow]).to be true
      end
    end
  end

  describe '#explain' do
    let(:actor) { 'user' }
    let(:actor_id) { 'alice' }
    let(:permission) { 'viewer' }
    let(:subject) { 'document' }
    let(:subject_id) { '123' }
    let(:context) { {} }

    context 'when no relationship exists' do
      before do
        allow(engine).to receive(:explain).and_return(nil)
      end

      it 'returns trace showing no relationship' do
        result = evaluator.explain(actor, actor_id, permission, subject, subject_id, context)
        expect(result[:allow]).to be false
        expect(result[:trace]).to be_an(Array)
        expect(result[:trace].first[:check]).to eq('relationship_exists')
        expect(result[:trace].first[:result]).to be false
      end
    end

    context 'with MFA requirement' do
      let!(:tuple) do
        RelTuple.create!(
          tenant_id: tenant_id,
          actor: actor,
          actor_id: actor_id,
          relation: permission,
          subject: subject,
          subject_id: subject_id
        )
      end

      let!(:entity_attrs) do
        AttributeVersion.create_version!(
          entity_type: subject,
          subject: subject,
          subject_id: subject_id,
          tenant_id: tenant_id,
          requires_mfa: true,
          metadata: {}
        )
      end

      before do
        allow(engine).to receive(:explain).and_return(['path'])
      end

      it 'returns detailed trace without MFA' do
        result = evaluator.explain(actor, actor_id, permission, subject, subject_id, {})
        expect(result[:allow]).to be false
        expect(result[:trace]).to be_an(Array)

        # Should have relationship check
        rel_check = result[:trace].find { |t| t[:check] == 'relationship_exists' }
        expect(rel_check[:result]).to be true

        # Should have MFA check
        mfa_check = result[:trace].find { |t| t[:check] == 'mfa_requirement' }
        expect(mfa_check[:result]).to be false
        expect(mfa_check[:details]).to include('MFA required but not verified')
        expect(mfa_check[:policy]).to be_present
      end

      it 'returns successful trace with MFA' do
        result = evaluator.explain(actor, actor_id, permission, subject, subject_id, { mfa_verified: true })
        expect(result[:allow]).to be true
        expect(result[:trace]).to be_an(Array)

        mfa_check = result[:trace].find { |t| t[:check] == 'mfa_requirement' }
        expect(mfa_check[:result]).to be true
        expect(mfa_check[:details]).to include('MFA verified')
      end
    end
  end
end
