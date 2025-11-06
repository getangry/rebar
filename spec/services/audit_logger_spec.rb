require "rails_helper"

RSpec.describe AuditLogger do
  let(:tenant_id) { "test-tenant" }
  let(:service_id) { "test-service" }
  let(:logger) do
    described_class.new(
      tenant_id: tenant_id,
      service_id: service_id,
      ip_address: "127.0.0.1",
      user_agent: "RSpec/1.0"
    )
  end

  before do
    AuditLog.where(tenant_id: tenant_id).delete_all
  end

  describe "#log_create" do
    it "creates an audit log for tuple creation" do
      logger.log_create(
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice",
        reason: "Test creation"
      )

      log = AuditLog.for_tenant(tenant_id).last
      expect(log).to be_present
      expect(log.action).to eq("create")
      expect(log.resource_type).to eq("rel_tuple")
      expect(log.subject).to eq("doc")
      expect(log.object_id).to eq("report-1")
      expect(log.relation).to eq("owner")
      expect(log.actor).to eq("user")
      expect(log.actor_id).to eq("alice")
      expect(log.reason).to eq("Test creation")
      expect(log.service_id).to eq(service_id)
      expect(log.ip_address).to eq("127.0.0.1")
    end

    it "stores after_state for create actions" do
      logger.log_create(
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice"
      )

      log = AuditLog.for_tenant(tenant_id).last
      expect(log.after_state).to eq({
        "subject" => "doc",
        "id" => "report-1",
        "relation" => "owner",
        "actor" => "user",
        "actor_id" => "alice"
      })
    end
  end

  describe "#log_delete" do
    it "creates an audit log for tuple deletion" do
      logger.log_delete(
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice",
        reason: "Access revoked"
      )

      log = AuditLog.for_tenant(tenant_id).last
      expect(log).to be_present
      expect(log.action).to eq("delete")
      expect(log.reason).to eq("Access revoked")
    end

    it "stores before_state for delete actions" do
      logger.log_delete(
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice"
      )

      log = AuditLog.for_tenant(tenant_id).last
      expect(log.before_state).to eq({
        "subject" => "doc",
        "id" => "report-1",
        "relation" => "owner",
        "actor" => "user",
        "actor_id" => "alice"
      })
    end
  end

  describe "#log_batch" do
    it "creates an audit log for batch operations" do
      logger.log_batch(
        action: "create",
        count: 5,
        reason: "Bulk import"
      )

      log = AuditLog.for_tenant(tenant_id).last
      expect(log).to be_present
      expect(log.action).to eq("batch_create")
      expect(log.metadata["count"]).to eq(5)
      expect(log.reason).to eq("Bulk import")
    end
  end

  describe "error handling" do
    it "does not raise errors if logging fails" do
      allow(AuditLog).to receive(:create!).and_raise(StandardError.new("DB error"))

      expect {
        logger.log_create(
          subject: "doc",
          id: "report-1",
          relation: "owner",
          actor: "user",
          actor_id: "alice"
        )
      }.not_to raise_error
    end
  end
end
