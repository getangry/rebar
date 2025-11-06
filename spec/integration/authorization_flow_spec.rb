require 'rails_helper'

RSpec.describe "Complete Authorization Flow", type: :request do
  let(:headers) do
    {
      "X-Service-Id" => "dev",
      "X-Tenant" => "acme-corp",
      "Content-Type" => "application/json"
    }
  end

  before do
    RelTuple.where(tenant_id: "acme-corp").delete_all
  end

  describe "Document Management System Scenario" do
    it "manages permissions for a hierarchical folder structure with groups" do
      # Setup organizational structure:
      # - alice is CEO
      # - bob is in eng team
      # - charlie is in marketing team
      # - Folders: /company/eng/, /company/marketing/
      # - Documents in each folder

      # Step 1: Create group memberships
      post "/tuples/batch", params: {
        tuples: [
          { subject: "group", id: "eng", relation: "member", actor: "user", actor_id: "bob" },
          { subject: "group", id: "marketing", relation: "member", actor: "user", actor_id: "charlie" }
        ]
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Step 2: Create folder hierarchy
      post "/tuples/batch", params: {
        tuples: [
          # Company folder owned by alice
          { subject: "folder", id: "company", relation: "owner", actor: "user", actor_id: "alice" },

          # Eng folder: parent is company, eng group are editors
          { subject: "folder", id: "eng", relation: "parent", actor: "folder", actor_id: "company" },
          { subject: "folder", id: "eng", relation: "editor", actor: "group", actor_id: "eng", actor_rel: "member" },

          # Marketing folder: parent is company, marketing group are editors
          { subject: "folder", id: "marketing", relation: "parent", actor: "folder", actor_id: "company" },
          { subject: "folder", id: "marketing", relation: "editor", actor: "group", actor_id: "marketing", actor_rel: "member" }
        ]
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Step 3: Create documents in folders
      post "/tuples/batch", params: {
        tuples: [
          # Eng doc
          { subject: "doc", id: "api-spec", relation: "parent", actor: "folder", actor_id: "eng" },

          # Marketing doc
          { subject: "doc", id: "campaign-2024", relation: "parent", actor: "folder", actor_id: "marketing" }
        ]
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Verify permissiosubject:

      # Alice (CEO) should be able to view everything (owns root folder)
      post "/auth/check", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "api-spec"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(true)

      post "/auth/check", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "campaign-2024"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(true)

      # Bob (eng) should access eng docs but not marketing
      post "/auth/check", params: {
        actor: "user",
        actor_id: "bob",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "api-spec"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(true)

      post "/auth/check", params: {
        actor: "user",
        actor_id: "bob",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "campaign-2024"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(false)

      # Charlie (marketing) should access marketing docs but not eng
      post "/auth/check", params: {
        actor: "user",
        actor_id: "charlie",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "campaign-2024"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(true)

      post "/auth/check", params: {
        actor: "user",
        actor_id: "charlie",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "api-spec"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(false)

      # Step 4: Share eng doc with charlie
      post "/tuples", params: {
        subject: "doc",
        id: "api-spec",
        relation: "viewer",
        actor: "user",
        actor_id: "charlie"
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Now charlie should be able to view eng doc
      post "/auth/check", params: {
        actor: "user",
        actor_id: "charlie",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "api-spec"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(true)

      # Step 5: Revoke charlie's direct access
      delete "/tuples", params: {
        subject: "doc",
        id: "api-spec",
        relation: "viewer",
        actor: "user",
        actor_id: "charlie"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)

      # Charlie should no longer have access
      post "/auth/check", params: {
        actor: "user",
        actor_id: "charlie",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "api-spec"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(false)
    end
  end

  describe "Nested Group Membership Scenario" do
    it "handles deeply nested organizational groups" do
      # Setup:
      # - alice in frontend team
      # - frontend team in eng department
      # - eng department in company-wide group
      # - doc owned by company-wide group

      post "/tuples/batch", params: {
        tuples: [
          # Group memberships
          { subject: "group", id: "frontend", relation: "member", actor: "user", actor_id: "alice" },
          { subject: "group", id: "eng", relation: "member", actor: "group", actor_id: "frontend" },
          { subject: "group", id: "all-staff", relation: "member", actor: "group", actor_id: "eng" },

          # Doc owned by all-staff
          { subject: "doc", id: "handbook", relation: "viewer", actor: "group", actor_id: "all-staff", actor_rel: "member" }
        ]
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Alice should be able to view handbook through nested groups
      post "/auth/check", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "handbook"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(true)

      # Get explanation of permission path
      post "/auth/explain", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "handbook"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["allow"]).to eq(true)
      expect(body["path"]).to be_present
    end
  end

  describe "Permission Inheritance Scenario" do
    it "properly inherits permissions through parent folder chain" do
      # Deep folder hierarchy: root -> projects -> 2024 -> q1 -> doc

      post "/tuples/batch", params: {
        tuples: [
          # Folder chain
          { subject: "folder", id: "projects", relation: "parent", actor: "folder", actor_id: "root" },
          { subject: "folder", id: "2024", relation: "parent", actor: "folder", actor_id: "projects" },
          { subject: "folder", id: "q1", relation: "parent", actor: "folder", actor_id: "2024" },
          { subject: "doc", id: "roadmap", relation: "parent", actor: "folder", actor_id: "q1" },

          # Alice owns root folder
          { subject: "folder", id: "root", relation: "owner", actor: "user", actor_id: "alice" }
        ]
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Alice should be able to view deep doc through inheritance
      post "/auth/check", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "roadmap"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)["allow"]).to eq(true)
    end
  end

  describe "Dynamic Permission Changes" do
    it "immediately reflects permission changes in checks" do
      # Bob doesn't have access initially
      post "/auth/check", params: {
        actor: "user",
        actor_id: "bob",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "secret"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(false)

      # Grant bob viewer permission
      post "/tuples", params: {
        subject: "doc",
        id: "secret",
        relation: "viewer",
        actor: "user",
        actor_id: "bob"
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Bob should now have access
      post "/auth/check", params: {
        actor: "user",
        actor_id: "bob",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "secret"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(true)

      # Revoke bob's permission
      delete "/tuples", params: {
        subject: "doc",
        id: "secret",
        relation: "viewer",
        actor: "user",
        actor_id: "bob"
      }.to_json, headers: headers

      expect(response).to have_http_status(:success)

      # Bob should no longer have access
      post "/auth/check", params: {
        actor: "user",
        actor_id: "bob",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "secret"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(false)
    end
  end

  describe "Multi-Tenant Isolation" do
    it "completely isolates permissions between tenants" do
      # Setup permissions in acme-corp
      post "/tuples", params: {
        subject: "doc",
        id: "budget",
        relation: "viewer",
        actor: "user",
        actor_id: "alice"
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Alice in acme-corp can view
      post "/auth/check", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "budget"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(true)

      # Switch to different tenant
      headers["X-Tenant"] = "globex-inc"

      # Alice in globex-inc should NOT have access
      post "/auth/check", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "budget"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(false)

      # Create permission in globex-inc
      post "/tuples", params: {
        subject: "doc",
        id: "budget",
        relation: "viewer",
        actor: "user",
        actor_id: "alice"
      }.to_json, headers: headers

      expect(response).to have_http_status(:created)

      # Now alice in globex-inc should have access
      post "/auth/check", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "budget"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(true)
    end
  end

  describe "Union Relation Permissions" do
    it "grants access through any path in union relations" do
      # According to schema:
      # doc.viewer = [editor, parent->viewer]
      # doc.editor = [owner]

      # Test path 1: User is editor -> can view
      post "/tuples", params: {
        subject: "doc",
        id: "report",
        relation: "editor",
        actor: "user",
        actor_id: "alice"
      }.to_json, headers: headers

      post "/auth/check", params: {
        actor: "user",
        actor_id: "alice",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "report"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(true)

      # Clean up
      RelTuple.where(tenant_id: "acme-corp").delete_all

      # Test path 2: User is owner -> can edit -> can view
      post "/tuples", params: {
        subject: "doc",
        id: "report",
        relation: "owner",
        actor: "user",
        actor_id: "bob"
      }.to_json, headers: headers

      post "/auth/check", params: {
        actor: "user",
        actor_id: "bob",
        permission: "viewer",
        obj_subject: "doc",
        subject_id: "report"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(true)

      post "/auth/check", params: {
        actor: "user",
        actor_id: "bob",
        permission: "editor",
        obj_subject: "doc",
        subject_id: "report"
      }.to_json, headers: headers

      expect(JSON.parse(response.body)["allow"]).to eq(true)
    end
  end
end
