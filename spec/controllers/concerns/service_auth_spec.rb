require 'rails_helper'

# Create a test controller to test the concern
class TestServiceAuthController < ApplicationController
  include ServiceAuth

  def index
    render json: { service_id: current_service[:id] }
  end

  def protected_action
    gate.allow_check!(tenant: "test", obj_ns: "doc", obj_id: "report-1", permission: "viewer")
    render json: { ok: true }
  end
end

RSpec.describe ServiceAuth, type: :controller do
  controller(TestServiceAuthController) do
    def index
      render json: { service_id: current_service[:id] }
    end

    def protected_action
      gate.allow_check!(tenant: "test", obj_ns: "doc", obj_id: "report-1", permission: "viewer")
      render json: { ok: true }
    end
  end

  describe "authentication" do
    context "with valid X-Service-Id header" do
      before do
        request.headers["X-Service-Id"] = "api-gateway"
      end

      it "authenticates successfully" do
        get :index

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body["service_id"]).to eq("api-gateway")
      end

      it "sets current_service" do
        get :index

        expect(controller.current_service).to be_present
        expect(controller.current_service[:id]).to eq("api-gateway")
      end

      it "authenticates for every request" do
        get :index
        expect(response).to have_http_status(:success)

        # Change service ID for next request
        request.headers["X-Service-Id"] = "different-service"

        get :index
        body = JSON.parse(response.body)
        expect(body["service_id"]).to eq("different-service")
      end
    end

    context "without X-Service-Id header" do
      it "raises ForbiddenError" do
        expect {
          get :index
        }.to raise_error(ForbiddenError, "missing service id")
      end
    end

    context "with empty X-Service-Id header" do
      before do
        request.headers["X-Service-Id"] = ""
      end

      it "raises ForbiddenError" do
        expect {
          get :index
        }.to raise_error(ForbiddenError, "missing service id")
      end
    end

    context "with whitespace-only X-Service-Id header" do
      before do
        request.headers["X-Service-Id"] = "   "
      end

      it "raises ForbiddenError" do
        expect {
          get :index
        }.to raise_error(ForbiddenError, "missing service id")
      end
    end
  end

  describe "#current_service" do
    before do
      request.headers["X-Service-Id"] = "test-service"
    end

    it "returns authenticated service object" do
      get :index

      service = controller.current_service
      expect(service).to be_a(Hash)
      expect(service[:id]).to eq("test-service")
      expect(service[:name]).to eq("test-service")
    end

    it "is available to controller actions" do
      get :index

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["service_id"]).to eq("test-service")
    end

    it "is memoized across calls" do
      get :index

      service1 = controller.current_service
      service2 = controller.current_service

      expect(service1.object_id).to eq(service2.object_id)
    end
  end

  describe "#gate" do
    before do
      request.headers["X-Service-Id"] = "dev"
    end

    it "returns PolicyGate instance" do
      get :index

      gate = controller.gate
      expect(gate).to be_a(PolicyGate)
    end

    it "initializes gate with current service" do
      get :index

      gate = controller.gate
      expect(gate.instance_variable_get(:@service_id)).to eq("dev")
    end

    it "is available for authorization checks" do
      get :protected_action

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["ok"]).to eq(true)
    end

    it "is memoized across calls" do
      get :index

      gate1 = controller.gate
      gate2 = controller.gate

      expect(gate1.object_id).to eq(gate2.object_id)
    end

    it "uses GrantRepo for fetching grants" do
      get :index

      gate = controller.gate
      grant_repo = gate.instance_variable_get(:@grants)

      # Gate should have loaded grants from GrantRepo
      expect(grant_repo).to be_present
    end
  end

  describe "before_action :authenticate_service!" do
    it "runs before every action" do
      # Without service header, should fail before reaching action
      expect {
        get :index
      }.to raise_error(ForbiddenError, "missing service id")

      # Action should not be executed
      expect(response.body).to be_empty
    end

    it "authenticates before authorization checks" do
      # Test that authentication happens before gate authorization

      # First, no header - should fail at authentication
      expect {
        get :protected_action
      }.to raise_error(ForbiddenError, "missing service id")

      # Now with header - should pass authentication
      request.headers["X-Service-Id"] = "dev"

      get :protected_action
      expect(response).to have_http_status(:success)
    end
  end

  describe "integration with AuthnRepo" do
    it "uses AuthnRepo for authentication" do
      authn_repo = instance_double(AuthnRepo)
      allow(AuthnRepo).to receive(:new).and_return(authn_repo)

      expect(authn_repo).to receive(:authenticate!).with("test-service").and_return({
        id: "test-service",
        name: "test-service"
      })

      request.headers["X-Service-Id"] = "test-service"

      get :index

      expect(response).to have_http_status(:success)
    end

    it "propagates AuthnRepo errors" do
      authn_repo = instance_double(AuthnRepo)
      allow(AuthnRepo).to receive(:new).and_return(authn_repo)
      allow(authn_repo).to receive(:authenticate!).and_raise(ForbiddenError, "invalid credentials")

      request.headers["X-Service-Id"] = "bad-service"

      expect {
        get :index
      }.to raise_error(ForbiddenError, "invalid credentials")
    end
  end

  describe "integration with PolicyGate" do
    before do
      request.headers["X-Service-Id"] = "restricted-service"
    end

    it "uses gate for authorization checks" do
      # Mock PolicyGate to deny access
      gate = instance_double(PolicyGate)
      allow(PolicyGate).to receive(:new).and_return(gate)
      allow(gate).to receive(:allow_check!).and_raise(ForbiddenError, "auth.check denied")

      expect {
        get :protected_action
      }.to raise_error(ForbiddenError, "auth.check denied")
    end
  end

  describe "development mode" do
    it "trusts X-Service-Id header" do
      # In development, any service ID is accepted
      service_ids = ["dev", "api-gateway", "web-app", "test-123"]

      service_ids.each do |service_id|
        request.headers["X-Service-Id"] = service_id

        get :index

        expect(response).to have_http_status(:success)
        body = JSON.parse(response.body)
        expect(body["service_id"]).to eq(service_id)
      end
    end

    it "documents production authentication TODO" do
      # Production should replace X-Service-Id with:
      # - Mutual TLS (mTLS) certificate validation
      # - JWT token with RS256 signature
      # - API key with cryptographic verification
      # - Service mesh identity (e.g., Istio, Linkerd)

      # Example production implementation:
      # def authenticate_service!
      #   cert = request.env['SSL_CLIENT_CERT']
      #   raise ForbiddenError, "missing client cert" unless cert
      #
      #   service = verify_mtls_certificate(cert)
      #   @current_service = AuthnRepo.new.authenticate!(service.id)
      # end

      expect(true).to eq(true) # Placeholder for documentation
    end
  end

  describe "error handling" do
    it "raises ForbiddenError for authentication failures" do
      expect {
        get :index
      }.to raise_error(ForbiddenError)
    end

    it "does not catch application errors" do
      # Allow other errors to propagate normally
      allow_any_instance_of(AuthnRepo).to receive(:authenticate!).and_raise(StandardError, "internal error")

      request.headers["X-Service-Id"] = "test"

      expect {
        get :index
      }.to raise_error(StandardError, "internal error")
    end
  end
end
