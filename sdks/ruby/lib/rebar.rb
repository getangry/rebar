require "faraday"
require "faraday/retry"
require "json"

module Rebar
  class Error < StandardError; end
  class APIError < Error; end
  class UnauthorizedError < APIError; end
  class ForbiddenError < APIError; end
  class NotFoundError < APIError; end

  class Client
    attr_reader :base_url, :service_id, :tenant

    ##
    # Initialize a new Rebar client
    #
    # @param base_url [String] Base URL of the Rebar API
    # @param service_id [String] Your service identifier
    # @param tenant [String] Tenant ID (default: "default")
    # @param timeout [Integer] Request timeout in seconds (default: 10)
    #
    # @example
    #   client = Rebar::Client.new(
    #     base_url: "http://localhost:3000",
    #     service_id: "my-app",
    #     tenant: "default"
    #   )
    def initialize(base_url:, service_id:, tenant: "default", timeout: 10)
      @base_url = base_url.sub(/\/$/, "")
      @service_id = service_id
      @tenant = tenant
      @timeout = timeout
      @connection = build_connection
    end

    ##
    # Check if an actor has a specific permission on a subject
    #
    # @param actor [String] Actor type (e.g., "user")
    # @param actor_id [String] Actor identifier
    # @param permission [String] Permission to check
    # @param subject [String] Subject type (e.g., "doc")
    # @param subject_id [String] Subject identifier
    # @return [Boolean] true if allowed, false otherwise
    #
    # @example
    #   allowed = client.check(
    #     actor: "user",
    #     actor_id: "alice",
    #     permission: "can_edit",
    #     subject: "doc",
    #     subject_id: "doc-123"
    #   )
    def check(actor:, actor_id:, permission:, subject:, subject_id:)
      response = post("/api/auth/check", {
        actor: actor,
        actor_id: actor_id,
        permission: permission,
        subject: subject,
        subject_id: subject_id
      })
      response["allow"]
    end

    ##
    # Check permission and get explanation path
    #
    # @return [Hash] Response with :allow and optional :path
    def explain(actor:, actor_id:, permission:, subject:, subject_id:)
      post("/api/auth/explain", {
        actor: actor,
        actor_id: actor_id,
        permission: permission,
        subject: subject,
        subject_id: subject_id
      })
    end

    ##
    # Create a relationship tuple
    #
    # @param subject [String] Subject type
    # @param id [String] Subject identifier
    # @param relation [String] Relation name
    # @param actor [String] Actor type
    # @param actor_id [String] Actor identifier
    # @param actor_rel [String, nil] Optional actor relation
    #
    # @example
    #   client.create_tuple(
    #     subject: "doc",
    #     id: "doc-123",
    #     relation: "editor",
    #     actor: "user",
    #     actor_id: "alice"
    #   )
    def create_tuple(subject:, id:, relation:, actor:, actor_id:, actor_rel: nil)
      post("/api/tuples", {
        subject: subject,
        id: id,
        relation: relation,
        actor: actor,
        actor_id: actor_id,
        actor_rel: actor_rel
      })
    end

    ##
    # Delete a relationship tuple
    def delete_tuple(subject:, id:, relation:, actor:, actor_id:, actor_rel: nil)
      delete("/api/tuples", {
        subject: subject,
        id: id,
        relation: relation,
        actor: actor,
        actor_id: actor_id,
        actor_rel: actor_rel
      })
    end

    ##
    # Batch create relationship tuples
    #
    # @param tuples [Array<Hash>] Array of tuple hashes
    #
    # @example
    #   client.batch_create_tuples([
    #     { subject: "doc", id: "doc-1", relation: "viewer", actor: "user", actor_id: "alice" },
    #     { subject: "doc", id: "doc-2", relation: "editor", actor: "user", actor_id: "bob" }
    #   ])
    def batch_create_tuples(tuples)
      post("/api/tuples/batch", { tuples: tuples })
    end

    ##
    # Batch delete relationship tuples
    def batch_delete_tuples(tuples)
      delete("/api/tuples/batch", { tuples: tuples })
    end

    ##
    # Get all permissions for an actor
    #
    # @param actor_type [String] Actor type (e.g., "user")
    # @param actor_id [String] Actor identifier
    # @return [Hash] Actor permissions with resources and actions
    #
    # @example
    #   permissions = client.actor_permissions("user", "alice")
    #   puts "Total permissions: #{permissions['total_permissions']}"
    #   permissions['resources'].each do |resource|
    #     puts "#{resource['resource']}: #{resource['actions']}"
    #   end
    def actor_permissions(actor_type, actor_id)
      get("/api/actors/#{actor_type}/#{actor_id}/permissions")
    end

    ##
    # Get all groups an actor is a member of
    #
    # @return [Hash] Actor group memberships
    def actor_groups(actor_type, actor_id)
      get("/api/actors/#{actor_type}/#{actor_id}/groups")
    end

    ##
    # Get audit logs
    #
    # @param page [Integer] Page number
    # @param per_page [Integer] Results per page
    # @param subject [String, nil] Filter by subject
    # @param actor [String, nil] Filter by actor
    # @param action [String, nil] Filter by action
    # @return [Hash] Audit logs with pagination
    def audit_logs(page: 1, per_page: 50, subject: nil, actor: nil, action: nil)
      params = { page: page, per_page: per_page }
      params[:subject] = subject if subject
      params[:actor] = actor if actor
      params[:action] = action if action

      get("/api/audit_logs", params)
    end

    ##
    # Get schema information
    def schema
      get("/api/schema")
    end

    ##
    # Change tenant for subsequent requests
    def tenant=(new_tenant)
      @tenant = new_tenant
    end

    private

    def build_connection
      Faraday.new(url: @base_url) do |f|
        f.request :json
        f.request :retry, max: 2, interval: 0.5
        f.response :json
        f.adapter Faraday.default_adapter
        f.options.timeout = @timeout
        f.options.open_timeout = @timeout
      end
    end

    def get(path, params = {})
      response = @connection.get(path) do |req|
        req.headers["X-Service-Id"] = @service_id
        req.headers["X-Tenant"] = @tenant
        req.params = params unless params.empty?
      end

      handle_response(response)
    end

    def post(path, body = {})
      response = @connection.post(path) do |req|
        req.headers["X-Service-Id"] = @service_id
        req.headers["X-Tenant"] = @tenant
        req.headers["Content-Type"] = "application/json"
        req.body = body.to_json
      end

      handle_response(response)
    end

    def delete(path, body = {})
      response = @connection.delete(path) do |req|
        req.headers["X-Service-Id"] = @service_id
        req.headers["X-Tenant"] = @tenant
        req.headers["Content-Type"] = "application/json"
        req.body = body.to_json
      end

      handle_response(response)
    end

    def handle_response(response)
      case response.status
      when 200..299
        response.body
      when 401
        raise UnauthorizedError, error_message(response)
      when 403
        raise ForbiddenError, error_message(response)
      when 404
        raise NotFoundError, error_message(response)
      else
        raise APIError, error_message(response)
      end
    end

    def error_message(response)
      if response.body.is_a?(Hash)
        response.body["error"] || response.body["message"] || "Unknown error"
      else
        "HTTP #{response.status}: #{response.reason_phrase}"
      end
    end
  end
end
