# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AttributeVersion, type: :model do
  let(:tenant_id) { 'test-tenant' }
  let(:entity_type) { 'document' }
  let(:subject_id) { 'doc-123' }

  describe '.create_version!' do
    it 'creates a new attribute version' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: { 'classification' => 'confidential' },
        requires_mfa: true,
        created_by: 'user:admin'
      )

      expect(version).to be_persisted
      expect(version.entity_type).to eq(entity_type)
      expect(version.subject_id).to eq(subject_id)
      expect(version.tenant_id).to eq(tenant_id)
      expect(version.requires_mfa).to be true
      expect(version.metadata['classification']).to eq('confidential')
      expect(version.version_number).to eq(1)
      expect(version.is_current).to be true
    end

    it 'closes previous version when creating new one' do
      version1 = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: { 'level' => '1' }
      )

      version2 = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: { 'level' => '2' }
      )

      version1.reload
      expect(version1.is_current).to be false
      expect(version1.valid_until).not_to eq(Float::INFINITY)

      expect(version2.is_current).to be true
      expect(version2.version_number).to eq(2)
      expect(version2.previous_version_id).to eq(version1.id)
    end

    it 'sets valid_from to current time' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: {}
      )

      expect(version.valid_from).to be_within(1.second).of(Time.current)
    end

    it 'sets valid_until to infinity by default' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: {}
      )

      expect(version.valid_until).to eq(Float::INFINITY)
    end
  end

  describe '.current_for' do
    let!(:version1) do
      described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: { 'v' => '1' }
      )
    end

    let!(:version2) do
      described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: { 'v' => '2' }
      )
    end

    it 'returns the current version' do
      current = described_class.current_for(entity_type, subject_id, tenant_id: tenant_id)
      expect(current.id).to eq(version2.id)
      expect(current.metadata['v']).to eq('2')
    end

    it 'returns nil if no current version exists' do
      current = described_class.current_for(entity_type, 'nonexistent', tenant_id: tenant_id)
      expect(current).to be_nil
    end
  end

  describe '.history_for' do
    before do
      3.times do |i|
        described_class.create_version!(
          entity_type: entity_type,
          subject: entity_type,
          subject_id: subject_id,
          tenant_id: tenant_id,
          metadata: { 'version' => i.to_s }
        )
      end
    end

    it 'returns all versions in descending order' do
      history = described_class.history_for(entity_type, subject_id, tenant_id: tenant_id)
      expect(history.size).to eq(3)
      expect(history.map { |v| v.metadata['version'] }).to eq(['2', '1', '0'])
    end
  end

  describe '.at_time' do
    let!(:version1) do
      described_class.create!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: { 'v' => '1' },
        valid_from: 2.days.ago,
        valid_until: 1.day.ago
      )
    end

    let!(:version2) do
      described_class.create!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: { 'v' => '2' },
        valid_from: 1.day.ago,
        valid_until: Float::INFINITY
      )
    end

    it 'returns version valid at specified time' do
      version = described_class.at_time(entity_type, subject_id, 36.hours.ago, tenant_id: tenant_id)
      expect(version.id).to eq(version1.id)
    end

    it 'returns current version for recent time' do
      version = described_class.at_time(entity_type, subject_id, Time.current, tenant_id: tenant_id)
      expect(version.id).to eq(version2.id)
    end
  end

  describe 'is_current computed column' do
    it 'is true when valid_until is infinity' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: {}
      )

      expect(version.is_current).to be true
    end

    it 'is false when valid_until is set' do
      version = described_class.create!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        metadata: {},
        valid_from: 2.days.ago,
        valid_until: 1.day.ago
      )

      expect(version.is_current).to be false
    end
  end

  describe 'hot attributes' do
    it 'stores requires_mfa as indexed column' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        requires_mfa: true,
        metadata: {}
      )

      expect(version.requires_mfa).to be true
    end

    it 'stores risk_level as indexed column' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        risk_level: 'high',
        metadata: {}
      )

      expect(version.risk_level).to eq('high')
    end

    it 'stores max_requests and current_requests' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        max_requests: 1000,
        current_requests: 50,
        metadata: {}
      )

      expect(version.max_requests).to eq(1000)
      expect(version.current_requests).to eq(50)
    end
  end

  describe 'audit trail' do
    it 'records created_by' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        created_by: 'user:admin',
        metadata: {}
      )

      expect(version.created_by).to eq('user:admin')
    end

    it 'records change_reason' do
      version = described_class.create_version!(
        entity_type: entity_type,
        subject: entity_type,
        subject_id: subject_id,
        tenant_id: tenant_id,
        change_reason: 'Security policy update',
        metadata: {}
      )

      expect(version.change_reason).to eq('Security policy update')
    end
  end
end
