# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RelTupleAttribute, type: :model do
  let(:tenant_id) { 'test-tenant' }
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

  describe '.create_version!' do
    it 'creates a new relationship attribute version' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: { 'grant_reason' => 'Project collaboration' },
        max_usage: 100,
        usage_count: 0,
        granted_by: 'user:manager',
        created_by: 'system'
      )

      expect(version).to be_persisted
      expect(version.tuple_id).to eq(tuple.id)
      expect(version.tenant_id).to eq(tenant_id)
      expect(version.max_usage).to eq(100)
      expect(version.usage_count).to eq(0)
      expect(version.granted_by).to eq('user:manager')
      expect(version.metadata['grant_reason']).to eq('Project collaboration')
      expect(version.version_number).to eq(1)
      expect(version.is_current).to be true
    end

    it 'closes previous version when creating new one' do
      version1 = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        max_usage: 100
      )

      version2 = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        max_usage: 200
      )

      version1.reload
      expect(version1.is_current).to be false
      expect(version1.valid_until).not_to eq(Float::INFINITY)

      expect(version2.is_current).to be true
      expect(version2.version_number).to eq(2)
      expect(version2.previous_version_id).to eq(version1.id)
    end
  end

  describe '.current_for' do
    let!(:version1) do
      described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: { 'v' => '1' }
      )
    end

    let!(:version2) do
      described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: { 'v' => '2' }
      )
    end

    it 'returns the current version' do
      current = described_class.current_for(tuple.id, tenant_id: tenant_id)
      expect(current.id).to eq(version2.id)
      expect(current.metadata['v']).to eq('2')
    end

    it 'returns nil if no current version exists' do
      other_tuple = RelTuple.create!(
        tenant_id: tenant_id,
        actor: 'user',
        actor_id: 'bob',
        relation: 'editor',
        subject: 'document',
        subject_id: 'doc-456'
      )

      current = described_class.current_for(other_tuple.id, tenant_id: tenant_id)
      expect(current).to be_nil
    end
  end

  describe 'usage limit attributes' do
    it 'tracks usage count and max usage' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        max_usage: 5,
        usage_count: 0
      )

      expect(version.max_usage).to eq(5)
      expect(version.usage_count).to eq(0)
    end

    it 'increments usage count' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        max_usage: 5,
        usage_count: 0
      )

      version.update!(usage_count: version.usage_count + 1)
      expect(version.reload.usage_count).to eq(1)
    end
  end

  describe 'approval workflow attributes' do
    it 'stores approval_required and approval_status' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: { 'ticket_id' => 'JIRA-123' },
        approval_required: true,
        approval_status: 'pending'
      )

      expect(version.approval_required).to be true
      expect(version.approval_status).to eq('pending')
      expect(version.metadata['ticket_id']).to eq('JIRA-123')
    end

    it 'allows approval status transitions' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        approval_required: true,
        approval_status: 'pending'
      )

      # Create new version with approved status
      approved_version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        approval_required: true,
        approval_status: 'approved'
      )

      expect(approved_version.approval_status).to eq('approved')
      expect(version.reload.is_current).to be false
    end
  end

  describe 'granted_by attribute' do
    it 'tracks who granted the permission' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        granted_by: 'user:admin'
      )

      expect(version.granted_by).to eq('user:admin')
    end
  end

  describe 'temporal validity' do
    it 'sets valid_from to current time' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {}
      )

      expect(version.valid_from).to be_within(1.second).of(Time.current)
    end

    it 'sets valid_until to infinity by default' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {}
      )

      expect(version.valid_until).to eq(Float::INFINITY)
    end

    it 'can set expiration time' do
      expiration = 7.days.from_now
      version = described_class.create!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        valid_from: Time.current,
        valid_until: expiration
      )

      expect(version.valid_until).to be_within(1.second).of(expiration)
    end
  end

  describe 'is_current computed column' do
    it 'is true when valid_until is infinity' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {}
      )

      expect(version.is_current).to be true
    end

    it 'is false when valid_until is set' do
      version = described_class.create!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {},
        valid_from: 2.days.ago,
        valid_until: 1.day.ago
      )

      expect(version.is_current).to be false
    end
  end

  describe 'audit trail' do
    it 'records created_by' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        created_by: 'user:admin',
        metadata: {}
      )

      expect(version.created_by).to eq('user:admin')
    end

    it 'records change_reason' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        change_reason: 'Extended access period',
        metadata: {}
      )

      expect(version.change_reason).to eq('Extended access period')
    end
  end

  describe 'cascade delete with tuple' do
    it 'deletes attributes when tuple is deleted' do
      version = described_class.create_version!(
        tuple_id: tuple.id,
        tenant_id: tenant_id,
        metadata: {}
      )

      expect { tuple.destroy }.to change { described_class.count }.by(-1)
      expect(described_class.find_by(id: version.id)).to be_nil
    end
  end
end
