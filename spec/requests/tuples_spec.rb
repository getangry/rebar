require 'rails_helper'

RSpec.describe "Tuples API", type: :request do
  let(:headers) do
    {
      "Authorization" => "Bearer dev",
      "X-Tenant" => "test-tenant",
      "Content-Type" => "application/json"
    }
  end

  before do
    RelTuple.where(tenant_id: "test-tenant").delete_all
  end

  describe "POST /tuples" do
    context "with valid parameters" do
      it "creates a relationship tuple" do
        expect {
          post "/tuples", params: {
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          }.to_json, headers: headers
        }.to change { RelTuple.count }.by(1)

        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to eq({ "ok" => true })

        tuple = RelTuple.last
        expect(tuple.tenant_id).to eq("test-tenant")
        expect(tuple.ns).to eq("doc")
        expect(tuple.id).to eq("report-1")
        expect(tuple.relation).to eq("owner")
        expect(tuple.subj_ns).to eq("user")
        expect(tuple.subj_id).to eq("alice")
      end

      it "creates a relationship with subj_rel (group membership)" do
        post "/tuples", params: {
          ns: "folder",
          id: "finance",
          relation: "viewer",
          subj_ns: "group",
          subj_id: "contractors",
          subj_rel: "member"
        }.to_json, headers: headers

        expect(response).to have_http_status(:created)

        tuple = RelTuple.last
        expect(tuple.subj_rel).to eq("member")
      end

      it "is idempotent (doesn't fail on duplicate)" do
        params = {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }

        post "/tuples", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        post "/tuples", params: params.to_json, headers: headers
        expect(response).to have_http_status(:created)

        expect(RelTuple.count).to eq(1)
      end
    end

    context "without service authentication" do
      it "returns forbidden" do
        post "/tuples", params: {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }.to_json, headers: headers.except("Authorization")

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with multi-tenant isolation" do
      it "creates tuple in correct tenant" do
        headers["X-Tenant"] = "tenant-a"

        post "/tuples", params: {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }.to_json, headers: headers

        expect(response).to have_http_status(:created)
        expect(RelTuple.where(tenant_id: "tenant-a").count).to eq(1)
        expect(RelTuple.where(tenant_id: "test-tenant").count).to eq(0)
      end
    end
  end

  describe "DELETE /tuples" do
    before do
      RelTuple.create!(
        tenant_id: "test-tenant",
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )
    end

    context "with valid parameters" do
      it "deletes an existing relationship" do
        expect {
          delete "/tuples", params: {
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          }.to_json, headers: headers
        }.to change { RelTuple.count }.by(-1)

        expect(response).to have_http_status(:success)
        expect(JSON.parse(response.body)).to eq({ "ok" => true })
      end

      it "is idempotent (doesn't fail on missing tuple)" do
        delete "/tuples", params: {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)

        delete "/tuples", params: {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
      end
    end

    context "without service authentication" do
      it "returns forbidden" do
        delete "/tuples", params: {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }.to_json, headers: headers.except("Authorization")

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with multi-tenant isolation" do
      it "only deletes from correct tenant" do
        # Create tuple in different tenant
        RelTuple.create!(
          tenant_id: "other-tenant",
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        )

        # Try to delete from test-tenant
        delete "/tuples", params: {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)

        # Tuple in test-tenant should be deleted
        expect(RelTuple.where(tenant_id: "test-tenant").count).to eq(0)

        # Tuple in other-tenant should still exist
        expect(RelTuple.where(tenant_id: "other-tenant").count).to eq(1)
      end
    end
  end

  describe "POST /tuples/batch" do
    context "with valid parameters" do
      it "creates multiple tuples in one request" do
        expect {
          post "/tuples/batch", params: {
            tuples: [
              {
                ns: "doc",
                id: "report-1",
                relation: "owner",
                subj_ns: "user",
                subj_id: "alice"
              },
              {
                ns: "doc",
                id: "report-1",
                relation: "editor",
                subj_ns: "user",
                subj_id: "bob"
              },
              {
                ns: "group",
                id: "eng",
                relation: "member",
                subj_ns: "user",
                subj_id: "charlie"
              }
            ]
          }.to_json, headers: headers
        }.to change { RelTuple.count }.by(3)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["ok"]).to eq(true)
        expect(body["count"]).to eq(3)
      end

      it "handles empty batch" do
        post "/tuples/batch", params: {
          tuples: []
        }.to_json, headers: headers

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["count"]).to eq(0)
      end

      it "sets up complex permission structure" do
        post "/tuples/batch", params: {
          tuples: [
            # alice is member of eng group
            { ns: "group", id: "eng", relation: "member", subj_ns: "user", subj_id: "alice" },
            # eng group owns folder
            { ns: "folder", id: "projects", relation: "owner", subj_ns: "group", subj_id: "eng", subj_rel: "member" },
            # doc has folder as parent
            { ns: "doc", id: "api-spec", relation: "parent", subj_ns: "folder", subj_id: "projects" }
          ]
        }.to_json, headers: headers

        expect(response).to have_http_status(:created)
        expect(RelTuple.count).to eq(3)

        # Verify alice can view the doc through the permission chain
        repo = RebacRepo.new(tenant: "test-tenant")
        engine = PermissionEngine.new(repo: repo)
        expect(engine.check("user", "alice", "viewer", "doc", "api-spec")).to eq(true)
      end
    end

    context "without service authentication" do
      it "returns forbidden" do
        post "/tuples/batch", params: {
          tuples: [
            { ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice" }
          ]
        }.to_json, headers: headers.except("Authorization")

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /tuples/batch" do
    before do
      RelTuple.create!(tenant_id: "test-tenant", ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice")
      RelTuple.create!(tenant_id: "test-tenant", ns: "doc", id: "report-1", relation: "editor", subj_ns: "user", subj_id: "bob")
      RelTuple.create!(tenant_id: "test-tenant", ns: "group", id: "eng", relation: "member", subj_ns: "user", subj_id: "charlie")
    end

    context "with valid parameters" do
      it "deletes multiple tuples in one request" do
        expect {
          delete "/tuples/batch", params: {
            tuples: [
              {
                ns: "doc",
                id: "report-1",
                relation: "owner",
                subj_ns: "user",
                subj_id: "alice"
              },
              {
                ns: "doc",
                id: "report-1",
                relation: "editor",
                subj_ns: "user",
                subj_id: "bob"
              }
            ]
          }.to_json, headers: headers
        }.to change { RelTuple.count }.by(-2)

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body["ok"]).to eq(true)
        expect(body["count"]).to eq(2)

        # Charlie's group membership should still exist
        expect(RelTuple.where(subj_id: "charlie").count).to eq(1)
      end

      it "handles empty batch" do
        expect {
          delete "/tuples/batch", params: {
            tuples: []
          }.to_json, headers: headers
        }.not_to change { RelTuple.count }

        expect(response).to have_http_status(:success)
      end

      it "is idempotent" do
        delete "/tuples/batch", params: {
          tuples: [
            { ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice" }
          ]
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)

        # Try again - should not fail
        delete "/tuples/batch", params: {
          tuples: [
            { ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice" }
          ]
        }.to_json, headers: headers

        expect(response).to have_http_status(:success)
      end
    end

    context "without service authentication" do
      it "returns forbidden" do
        delete "/tuples/batch", params: {
          tuples: [
            { ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice" }
          ]
        }.to_json, headers: headers.except("Authorization")

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "authorization via PolicyGate" do
    context "when service lacks tuple write permissions" do
      before do
        # Mock a restricted service
        allow_any_instance_of(PolicyGate).to receive(:allow_tuple_write!).and_raise(
          ForbiddenError.new("tuples.write denied")
        )
      end

      it "rejects tuple creation" do
        post "/tuples", params: {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }.to_json, headers: headers

        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to have_key("error")
      end

      it "rejects tuple deletion" do
        RelTuple.create!(
          tenant_id: "test-tenant",
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        )

        delete "/tuples", params: {
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        }.to_json, headers: headers

        expect(response).to have_http_status(:forbidden)
      end

      it "rejects batch operations" do
        post "/tuples/batch", params: {
          tuples: [
            { ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice" }
          ]
        }.to_json, headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
