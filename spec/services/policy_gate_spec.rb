require 'rails_helper'

RSpec.describe PolicyGate do
  let(:grant_repo) { double("GrantRepo") }
  let(:service_id) { "test-service" }
  let(:gate) { described_class.new(service_id: service_id, grant_repo: grant_repo) }

  describe "#allow_tuple_write!" do
    context "with full wildcard grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: nil,
            ns: nil,
            relations: nil,
            object_prefix: nil,
            subject_ns: nil,
            subject_prefix: nil
          }
        ])
      end

      it "allows any tuple write" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.not_to raise_error
      end
    end

    context "with tenant-scoped grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: "acme",
            ns: nil,
            relations: nil,
            object_prefix: nil,
            subject_ns: nil,
            subject_prefix: nil
          }
        ])
      end

      it "allows writes in the granted tenant" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.not_to raise_error
      end

      it "denies writes in other tenants" do
        expect {
          gate.allow_tuple_write!(
            tenant: "other-tenant",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.to raise_error(ForbiddenError, "tuples.write denied")
      end
    end

    context "with namespace-scoped grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: nil,
            ns: "doc",
            relations: nil,
            object_prefix: nil,
            subject_ns: nil,
            subject_prefix: nil
          }
        ])
      end

      it "allows writes in the granted namespace" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.not_to raise_error
      end

      it "denies writes in other namespaces" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "folder",
            id: "finance",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.to raise_error(ForbiddenError, "tuples.write denied")
      end
    end

    context "with relation-scoped grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: nil,
            ns: nil,
            relations: ["viewer", "editor"],
            object_prefix: nil,
            subject_ns: nil,
            subject_prefix: nil
          }
        ])
      end

      it "allows writes for granted relations" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "viewer",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.not_to raise_error

        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "editor",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.not_to raise_error
      end

      it "denies writes for non-granted relations" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.to raise_error(ForbiddenError, "tuples.write denied")
      end
    end

    context "with object prefix grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: nil,
            ns: nil,
            relations: nil,
            object_prefix: "team-eng:",
            subject_ns: nil,
            subject_prefix: nil
          }
        ])
      end

      it "allows writes for objects with matching prefix" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "team-eng:report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.not_to raise_error

        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "team-eng:plan-2024",
            relation: "viewer",
            subj_ns: "user",
            subj_id: "bob"
          )
        }.not_to raise_error
      end

      it "denies writes for objects without matching prefix" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "team-marketing:report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.to raise_error(ForbiddenError, "tuples.write denied")
      end
    end

    context "with subject namespace grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: nil,
            ns: nil,
            relations: nil,
            object_prefix: nil,
            subject_ns: "user",
            subject_prefix: nil
          }
        ])
      end

      it "allows writes for granted subject namespace" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.not_to raise_error
      end

      it "denies writes for other subject namespaces" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "group",
            subj_id: "eng"
          )
        }.to raise_error(ForbiddenError, "tuples.write denied")
      end
    end

    context "with subject prefix grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: nil,
            ns: nil,
            relations: nil,
            object_prefix: nil,
            subject_ns: nil,
            subject_prefix: "svc:"
          }
        ])
      end

      it "allows writes for subjects with matching prefix" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "svc:api-server"
          )
        }.not_to raise_error
      end

      it "denies writes for subjects without matching prefix" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.to raise_error(ForbiddenError, "tuples.write denied")
      end
    end

    context "with multiple grants" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: "acme",
            ns: "doc",
            relations: nil,
            object_prefix: nil,
            subject_ns: nil,
            subject_prefix: nil
          },
          {
            action: "tuples.write",
            tenant_id: "globex",
            ns: "folder",
            relations: nil,
            object_prefix: nil,
            subject_ns: nil,
            subject_prefix: nil
          }
        ])
      end

      it "allows writes matching any grant (OR logic)" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.not_to raise_error

        expect {
          gate.allow_tuple_write!(
            tenant: "globex",
            ns: "folder",
            id: "finance",
            relation: "owner",
            subj_ns: "user",
            subj_id: "bob"
          )
        }.not_to raise_error
      end

      it "denies writes not matching any grant" do
        expect {
          gate.allow_tuple_write!(
            tenant: "globex",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.to raise_error(ForbiddenError, "tuples.write denied")
      end
    end

    context "with combined constraints" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: "acme",
            ns: "doc",
            relations: ["viewer"],
            object_prefix: "public:",
            subject_ns: "user",
            subject_prefix: "external:"
          }
        ])
      end

      it "allows writes matching all constraints (AND logic)" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "public:readme",
            relation: "viewer",
            subj_ns: "user",
            subj_id: "external:partner-1"
          )
        }.not_to raise_error
      end

      it "denies writes failing any constraint" do
        # Wrong tenant
        expect {
          gate.allow_tuple_write!(
            tenant: "globex",
            ns: "doc",
            id: "public:readme",
            relation: "viewer",
            subj_ns: "user",
            subj_id: "external:partner-1"
          )
        }.to raise_error(ForbiddenError)

        # Wrong namespace
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "folder",
            id: "public:readme",
            relation: "viewer",
            subj_ns: "user",
            subj_id: "external:partner-1"
          )
        }.to raise_error(ForbiddenError)

        # Wrong relation
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "public:readme",
            relation: "editor",
            subj_ns: "user",
            subj_id: "external:partner-1"
          )
        }.to raise_error(ForbiddenError)

        # Wrong object prefix
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "private:secret",
            relation: "viewer",
            subj_ns: "user",
            subj_id: "external:partner-1"
          )
        }.to raise_error(ForbiddenError)

        # Wrong subject namespace
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "public:readme",
            relation: "viewer",
            subj_ns: "group",
            subj_id: "external:partners"
          )
        }.to raise_error(ForbiddenError)

        # Wrong subject prefix
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "public:readme",
            relation: "viewer",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.to raise_error(ForbiddenError)
      end
    end
  end

  describe "#allow_check!" do
    context "with full wildcard grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "auth.check",
            tenant_id: nil,
            ns: nil,
            object_prefix: nil
          }
        ])
      end

      it "allows any check" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "doc",
            obj_id: "report-1",
            permission: "viewer"
          )
        }.not_to raise_error
      end
    end

    context "with tenant-scoped grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "auth.check",
            tenant_id: "acme",
            ns: nil,
            object_prefix: nil
          }
        ])
      end

      it "allows checks in the granted tenant" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "doc",
            obj_id: "report-1",
            permission: "viewer"
          )
        }.not_to raise_error
      end

      it "denies checks in other tenants" do
        expect {
          gate.allow_check!(
            tenant: "globex",
            obj_ns: "doc",
            obj_id: "report-1",
            permission: "viewer"
          )
        }.to raise_error(ForbiddenError, "auth.check denied")
      end
    end

    context "with namespace-scoped grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "auth.check",
            tenant_id: nil,
            ns: "doc",
            object_prefix: nil
          }
        ])
      end

      it "allows checks in the granted namespace" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "doc",
            obj_id: "report-1",
            permission: "viewer"
          )
        }.not_to raise_error
      end

      it "denies checks in other namespaces" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "folder",
            obj_id: "finance",
            permission: "viewer"
          )
        }.to raise_error(ForbiddenError, "auth.check denied")
      end
    end

    context "with object prefix grant" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "auth.check",
            tenant_id: nil,
            ns: nil,
            object_prefix: "app:"
          }
        ])
      end

      it "allows checks for objects with matching prefix" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "doc",
            obj_id: "app:dashboard",
            permission: "viewer"
          )
        }.not_to raise_error
      end

      it "denies checks for objects without matching prefix" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "doc",
            obj_id: "admin:settings",
            permission: "viewer"
          )
        }.to raise_error(ForbiddenError, "auth.check denied")
      end
    end

    context "with multiple grants" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "auth.check",
            tenant_id: "acme",
            ns: "doc",
            object_prefix: nil
          },
          {
            action: "auth.check",
            tenant_id: "globex",
            ns: "folder",
            object_prefix: nil
          }
        ])
      end

      it "allows checks matching any grant" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "doc",
            obj_id: "report-1",
            permission: "viewer"
          )
        }.not_to raise_error

        expect {
          gate.allow_check!(
            tenant: "globex",
            obj_ns: "folder",
            obj_id: "finance",
            permission: "viewer"
          )
        }.not_to raise_error
      end

      it "denies checks not matching any grant" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "folder",
            obj_id: "finance",
            permission: "viewer"
          )
        }.to raise_error(ForbiddenError, "auth.check denied")
      end
    end

    context "with no matching action" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([
          {
            action: "tuples.write",
            tenant_id: nil,
            ns: nil,
            relations: nil,
            object_prefix: nil,
            subject_ns: nil,
            subject_prefix: nil
          }
        ])
      end

      it "denies checks when only tuples.write is granted" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "doc",
            obj_id: "report-1",
            permission: "viewer"
          )
        }.to raise_error(ForbiddenError, "auth.check denied")
      end
    end

    context "with no grants at all" do
      before do
        allow(grant_repo).to receive(:grants_for).with(service_id).and_return([])
      end

      it "denies all checks" do
        expect {
          gate.allow_check!(
            tenant: "acme",
            obj_ns: "doc",
            obj_id: "report-1",
            permission: "viewer"
          )
        }.to raise_error(ForbiddenError, "auth.check denied")
      end

      it "denies all tuple writes" do
        expect {
          gate.allow_tuple_write!(
            tenant: "acme",
            ns: "doc",
            id: "report-1",
            relation: "owner",
            subj_ns: "user",
            subj_id: "alice"
          )
        }.to raise_error(ForbiddenError, "tuples.write denied")
      end
    end
  end
end
