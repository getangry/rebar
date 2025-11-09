require "rails_helper"

RSpec.describe "Audit Logs API", type: :request do
  let(:headers) do
    {
      "Authorization" => "Bearer dev",
      "X-Tenant" => "test-audit",
      "Content-Type" => "application/json"
    }
  end

  before do
    AuditLog.where(tenant_id: "test-audit").delete_all
    RelTuple.where(tenant_id: "test-audit").delete_all
  end

  describe "GET /api/audit_logs" do
    before do
      # Create some test data
      3.times do |i|
        post "/api/tuples", params: {
          subject: "doc",
          id: "report-#{i}",
          relation: "owner",
          actor: "user",
          actor_id: "alice",
          reason: "Test creation #{i}"
        }.to_json, headers: headers
      end
    end

    it "returns audit logs for the tenant" do
      get "/api/audit_logs", headers: headers

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["logs"]).to be_an(Array)
      expect(body["logs"].size).to eq(3)
      expect(body["logs"].first).to have_key("action")
      expect(body["logs"].first).to have_key("tuple")
      expect(body["logs"].first).to have_key("reason")
    end

    it "filters by action" do
      # Delete one tuple
      delete "/api/tuples", params: {
        subject: "doc",
        id: "report-0",
        relation: "owner",
        actor: "user",
        actor_id: "alice"
      }.to_json, headers: headers

      get "/api/audit_logs", params: { action: "delete" }, headers: headers

      body = JSON.parse(response.body)
      expect(body["logs"].size).to eq(1)
      expect(body["logs"].first["action"]).to eq("delete")
    end

    it "filters by service_id" do
      get "/api/audit_logs", params: { service_id: "dev" }, headers: headers

      body = JSON.parse(response.body)
      expect(body["logs"].size).to eq(3)
      expect(body["logs"].all? { |l| l["service_id"] == "dev" }).to be true
    end

    it "supports pagination" do
      get "/api/audit_logs", params: { per_page: 2, page: 1 }, headers: headers

      body = JSON.parse(response.body)
      expect(body["logs"].size).to eq(2)
      expect(body["page"]).to eq(1)
      expect(body["per_page"]).to eq(2)
    end
  end

  describe "GET /api/audit_logs/:id" do
    it "returns a specific audit log" do
      post "/api/tuples", params: {
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice",
        reason: "Initial setup"
      }.to_json, headers: headers

      log_id = AuditLog.for_tenant("test-audit").last.id

      get "/api/audit_logs/#{log_id}", headers: headers

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(log_id)
      expect(body["reason"]).to eq("Initial setup")
    end

    it "returns 404 for non-existent log" do
      get "/api/audit_logs/99999", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/audit_logs/tuple_history" do
    it "returns history for a specific tuple" do
      # Create tuple
      post "/api/tuples", params: {
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice",
        reason: "Initial creation"
      }.to_json, headers: headers

      # Delete tuple
      delete "/api/tuples", params: {
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice",
        reason: "Cleanup"
      }.to_json, headers: headers

      # Get history
      get "/api/audit_logs/tuple_history", params: {
        subject: "doc",
        object_id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice"
      }, headers: headers

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["history"].size).to eq(2)
      expect(body["history"].first["action"]).to eq("delete")  # Most recent first
      expect(body["history"].last["action"]).to eq("create")
    end

    it "requires all tuple parameters" do
      get "/api/audit_logs/tuple_history", params: {
        subject: "doc"
      }, headers: headers

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body["error"]).to include("Missing required parameters")
    end
  end

  describe "GET /api/audit_logs/stats" do
    before do
      # Create some varied audit data
      post "/api/tuples", params: {
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice"
      }.to_json, headers: headers

      post "/api/tuples", params: {
        subject: "doc",
        id: "report-2",
        relation: "editor",
        actor: "user",
        actor_id: "bob"
      }.to_json, headers: headers

      delete "/api/tuples", params: {
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice"
      }.to_json, headers: headers
    end

    it "returns audit log statistics" do
      get "/api/audit_logs/stats", headers: headers

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["total_count"]).to eq(3)
      expect(body["by_action"]).to have_key("create")
      expect(body["by_action"]).to have_key("delete")
      expect(body["by_service"]).to have_key("dev")
    end
  end

  describe "audit logging integration" do
    it "logs tuple creation" do
      expect {
        post "/api/tuples", params: {
          subject: "doc",
          id: "report-1",
          relation: "owner",
          actor: "user",
          actor_id: "alice",
          reason: "Test reason"
        }.to_json, headers: headers
      }.to change { AuditLog.count }.by(1)

      log = AuditLog.last
      expect(log.action).to eq("create")
      expect(log.reason).to eq("Test reason")
      expect(log.ip_address).to be_present
    end

    it "logs tuple deletion" do
      # Create first
      post "/api/tuples", params: {
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice"
      }.to_json, headers: headers

      # Then delete
      expect {
        delete "/api/tuples", params: {
          subject: "doc",
          id: "report-1",
          relation: "owner",
          actor: "user",
          actor_id: "alice",
          reason: "Access revoked"
        }.to_json, headers: headers
      }.to change { AuditLog.where(action: "delete").count }.by(1)

      log = AuditLog.where(action: "delete").last
      expect(log.reason).to eq("Access revoked")
    end

    it "does not log on conflict (duplicate insert)" do
      # Create tuple
      post "/api/tuples", params: {
        subject: "doc",
        id: "report-1",
        relation: "owner",
        actor: "user",
        actor_id: "alice"
      }.to_json, headers: headers

      # Try to create same tuple again
      expect {
        post "/api/tuples", params: {
          subject: "doc",
          id: "report-1",
          relation: "owner",
          actor: "user",
          actor_id: "alice"
        }.to_json, headers: headers
      }.not_to change { AuditLog.count }
    end
  end
end
