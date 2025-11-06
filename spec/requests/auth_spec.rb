require 'rails_helper'

RSpec.describe "Auth API", type: :request do
  let(:repo) { RebacRepo.new(tenant: "test-tenant") }

  before do
    # Clean slate
    RelTuple.where(tenant_id: "test-tenant").delete_all
  end

  describe "POST /auth/check" do
    let(:headers) do
      {
        "X-Service-Id" => "dev",
        "X-Tenant" => "test-tenant",
        "Content-Type" => "application/json"
      }
    end

    context "when permission is granted" do
      before do
        repo.write(ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice")
      end

      it "returns allow: true for authorized access" do
        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "allow" => true })
      end

      it "returns allow: true for viewer when user is owner (union)" do
        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "viewer",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "allow" => true })
      end
    end

    context "when permission is denied" do
      it "returns allow: false for unauthorized access" do
        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "bob",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "nonexistent"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "allow" => false })
      end

      it "returns allow: false when object exists but user has no permission" do
        repo.write(ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice")

        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "bob",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "allow" => false })
      end
    end

    context "with group-based permissions" do
      before do
        repo.write(ns: "group", id: "eng", relation: "member", subj_ns: "user", subj_id: "alice")
        repo.write(ns: "doc", id: "report-1", relation: "viewer", subj_ns: "group", subj_id: "eng", subj_rel: "member")
      end

      it "returns allow: true for group member" do
        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "viewer",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "allow" => true })
      end
    end

    context "with parent inheritance" do
      before do
        repo.write(ns: "folder", id: "finance", relation: "owner", subj_ns: "user", subj_id: "alice")
        repo.write(ns: "doc", id: "budget", relation: "parent", subj_ns: "folder", subj_id: "finance")
      end

      it "returns allow: true for inherited permission" do
        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "viewer",
          obj_ns: "doc",
          obj_id: "budget"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "allow" => true })
      end
    end

    context "with multi-tenant isolation" do
      before do
        # alice owns doc in test-tenant
        repo.write(ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice")

        # bob owns same doc ID in different tenant
        other_repo = RebacRepo.new(tenant: "other-tenant")
        other_repo.write(ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "bob")
      end

      it "enforces tenant isolation - alice cannot access bob's doc" do
        headers["X-Tenant"] = "other-tenant"

        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "allow" => false })
      end

      it "allows bob to access his doc in his tenant" do
        headers["X-Tenant"] = "other-tenant"

        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "bob",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "allow" => true })
      end
    end

    context "without service authentication" do
      it "returns forbidden when X-Service-Id header is missing" do
        post "/auth/check", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers.except("X-Service-Id")

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to have_key("error")
      end
    end
  end

  describe "POST /auth/explain" do
    let(:headers) do
      {
        "X-Service-Id" => "dev",
        "X-Tenant" => "test-tenant",
        "Content-Type" => "application/json"
      }
    end

    context "when permission is granted" do
      before do
        repo.write(ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice")
      end

      it "returns allow: true with permission path" do
        post "/auth/explain", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)

        body = JSON.parse(response.body)
        expect(body["allow"]).to eq(true)
        expect(body["path"]).to be_present
        expect(body["path"]).to be_an(Array)
      end
    end

    context "when permission is denied" do
      it "returns allow: false without path" do
        post "/auth/explain", params: {
          subj_ns: "user",
          subj_id: "bob",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "nonexistent"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)

        body = JSON.parse(response.body)
        expect(body["allow"]).to eq(false)
        expect(body["path"]).to be_nil
      end
    end

    context "with complex permission path" do
      before do
        # alice -> eng group -> folder owner -> doc viewer (via parent)
        repo.write(ns: "group", id: "eng", relation: "member", subj_ns: "user", subj_id: "alice")
        repo.write(ns: "folder", id: "projects", relation: "owner", subj_ns: "group", subj_id: "eng", subj_rel: "member")
        repo.write(ns: "doc", id: "api-spec", relation: "parent", subj_ns: "folder", subj_id: "projects")
      end

      it "returns the complete permission resolution path" do
        post "/auth/explain", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "viewer",
          obj_ns: "doc",
          obj_id: "api-spec"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)

        body = JSON.parse(response.body)
        expect(body["allow"]).to eq(true)
        expect(body["path"]).to be_present
        expect(body["path"].length).to be > 0
      end
    end

    context "without service authentication" do
      it "returns forbidden when X-Service-Id header is missing" do
        post "/auth/explain", params: {
          subj_ns: "user",
          subj_id: "alice",
          permission: "owner",
          obj_ns: "doc",
          obj_id: "report-1"
        }.to_json, headers: headers.except("X-Service-Id")

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
