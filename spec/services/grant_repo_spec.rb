require 'rails_helper'

RSpec.describe GrantRepo do
  let(:repo) { described_class.new }

  describe "#grants_for" do
    context "with 'dev' service" do
      it "returns full wildcard grants for development" do
        grants = repo.grants_for("dev")

        expect(grants).to be_an(Array)
        expect(grants.length).to eq(2)

        auth_check_grant = grants.find { |g| g[:action] == "auth.check" }
        tuple_write_grant = grants.find { |g| g[:action] == "tuples.write" }

        expect(auth_check_grant).to be_present
        expect(auth_check_grant[:tenant_id]).to be_nil
        expect(auth_check_grant[:ns]).to be_nil
        expect(auth_check_grant[:object_prefix]).to be_nil

        expect(tuple_write_grant).to be_present
        expect(tuple_write_grant[:tenant_id]).to be_nil
        expect(tuple_write_grant[:ns]).to be_nil
        expect(tuple_write_grant[:object_prefix]).to be_nil
      end

      it "allows access to any tenant" do
        grants = repo.grants_for("dev")

        auth_grant = grants.find { |g| g[:action] == "auth.check" }
        expect(auth_grant[:tenant_id]).to be_nil # nil means all tenants
      end

      it "allows access to any namespace" do
        grants = repo.grants_for("dev")

        auth_grant = grants.find { |g| g[:action] == "auth.check" }
        expect(auth_grant[:ns]).to be_nil # nil means all namespaces
      end
    end

    context "with unknown service" do
      it "returns empty grants" do
        grants = repo.grants_for("unknown-service")

        expect(grants).to be_an(Array)
        expect(grants).to be_empty
      end

      it "returns empty grants for nil service" do
        grants = repo.grants_for(nil)

        expect(grants).to be_empty
      end

      it "returns empty grants for empty string" do
        grants = repo.grants_for("")

        expect(grants).to be_empty
      end
    end

    context "grant structure" do
      it "returns grants with correct keys for auth.check" do
        grants = repo.grants_for("dev")
        auth_grant = grants.find { |g| g[:action] == "auth.check" }

        expect(auth_grant).to have_key(:action)
        expect(auth_grant).to have_key(:tenant_id)
        expect(auth_grant).to have_key(:ns)
        expect(auth_grant).to have_key(:object_prefix)
      end

      it "returns grants with correct keys for tuples.write" do
        grants = repo.grants_for("dev")
        write_grant = grants.find { |g| g[:action] == "tuples.write" }

        expect(write_grant).to have_key(:action)
        expect(write_grant).to have_key(:tenant_id)
        expect(write_grant).to have_key(:ns)
        expect(write_grant).to have_key(:object_prefix)
      end
    end
  end

  describe "development mode behavior" do
    it "provides permissive grants to simplify testing" do
      # In development, the 'dev' service should have unrestricted access
      grants = repo.grants_for("dev")

      # Should be able to check any permission
      auth_grant = grants.find { |g| g[:action] == "auth.check" }
      expect(auth_grant[:tenant_id]).to be_nil
      expect(auth_grant[:ns]).to be_nil

      # Should be able to write any tuple
      write_grant = grants.find { |g| g[:action] == "tuples.write" }
      expect(write_grant[:tenant_id]).to be_nil
      expect(write_grant[:ns]).to be_nil
    end
  end

  describe "integration with PolicyGate" do
    it "provides grants that PolicyGate can consume" do
      grants = repo.grants_for("dev")

      # PolicyGate should be able to use these grants
      gate = PolicyGate.new(service_id: "dev", grant_repo: repo)

      expect {
        gate.allow_check!(
          tenant: "test",
          obj_ns: "doc",
          obj_id: "report-1",
          permission: "viewer"
        )
      }.not_to raise_error

      expect {
        gate.allow_tuple_write!(
          tenant: "test",
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        )
      }.not_to raise_error
    end
  end

  describe "future production implementation" do
    it "documents the interface for AR model implementation" do
      # This test documents what a production GrantRepo should do:
      # 1. Query service_grants table by service_id
      # 2. Return array of grant hashes with required keys
      # 3. Support filtering by tenant_id, ns, object_prefix, etc.

      # Example of what production code might look like:
      # def grants_for(service_id)
      #   ServiceGrant
      #     .joins(:service_account)
      #     .where(service_accounts: { id: service_id })
      #     .map do |grant|
      #       {
      #         action: grant.action,
      #         tenant_id: grant.tenant_id,
      #         ns: grant.ns,
      #         object_prefix: grant.object_prefix,
      #         relations: grant.relations,
      #         subject_ns: grant.subject_ns,
      #         subject_prefix: grant.subject_prefix
      #       }
      #     end
      # end

      expect(repo).to respond_to(:grants_for)
    end
  end
end
