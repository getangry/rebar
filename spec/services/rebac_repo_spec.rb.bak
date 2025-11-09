require 'rails_helper'

RSpec.describe RebacRepo do
  let(:repo) { described_class.new(tenant: "test-tenant") }

  before do
    # Clean slate for each test
    RelTuple.where(tenant_id: "test-tenant").delete_all
  end

  describe "#write" do
    it "creates a new relationship tuple" do
      expect {
        repo.write(
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        )
      }.to change { RelTuple.count }.by(1)

      tuple = RelTuple.last
      expect(tuple.tenant_id).to eq("test-tenant")
      expect(tuple.ns).to eq("doc")
      expect(tuple.id).to eq("report-1")
      expect(tuple.relation).to eq("owner")
      expect(tuple.subj_ns).to eq("user")
      expect(tuple.subj_id).to eq("alice")
      expect(tuple.subj_rel).to be_nil
    end

    it "creates a relationship with subject relation (group membership)" do
      repo.write(
        ns: "folder",
        id: "finance",
        relation: "viewer",
        subj_ns: "group",
        subj_id: "contractors",
        subj_rel: "member"
      )

      tuple = RelTuple.last
      expect(tuple.subj_rel).to eq("member")
    end

    it "is idempotent (doesn't duplicate on unique constraint)" do
      params = {
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      }

      repo.write(**params)

      expect {
        repo.write(**params)
      }.not_to change { RelTuple.count }
    end
  end

  describe "#delete" do
    before do
      repo.write(
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )
    end

    it "removes an existing relationship" do
      expect {
        repo.delete(
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        )
      }.to change { RelTuple.count }.by(-1)
    end

    it "is idempotent (no error on missing tuple)" do
      repo.delete(
        ns: "doc",
        id: "report-1",
        relation: "owner",
        subj_ns: "user",
        subj_id: "alice"
      )

      expect {
        repo.delete(
          ns: "doc",
          id: "report-1",
          relation: "owner",
          subj_ns: "user",
          subj_id: "alice"
        )
      }.not_to raise_error
    end
  end

  describe "#edges_for_object" do
    before do
      # Multiple users with different relations to a doc
      repo.write(ns: "doc", id: "report-1", relation: "owner", subj_ns: "user", subj_id: "alice")
      repo.write(ns: "doc", id: "report-1", relation: "editor", subj_ns: "user", subj_id: "bob")
      repo.write(ns: "doc", id: "report-1", relation: "viewer", subj_ns: "user", subj_id: "charlie")

      # Group with relation
      repo.write(ns: "doc", id: "report-1", relation: "viewer", subj_ns: "group", subj_id: "eng", subj_rel: "member")

      # Different doc (should not appear)
      repo.write(ns: "doc", id: "report-2", relation: "owner", subj_ns: "user", subj_id: "dave")
    end

    it "returns all subjects with the given relation to an object" do
      edges = repo.edges_for_object(ns: "doc", id: "report-1", relation: "viewer")

      expect(edges.length).to eq(2)

      user_edge = edges.find { |e| e[:subj_ns] == "user" }
      group_edge = edges.find { |e| e[:subj_ns] == "group" }

      expect(user_edge[:subj_id]).to eq("charlie")
      expect(user_edge[:subj_rel]).to be_nil

      expect(group_edge[:subj_id]).to eq("eng")
      expect(group_edge[:subj_rel]).to eq("member")
    end

    it "returns empty array when no edges exist" do
      edges = repo.edges_for_object(ns: "doc", id: "nonexistent", relation: "owner")
      expect(edges).to be_empty
    end

    it "filters by tenant" do
      # Create tuple in different tenant
      other_repo = described_class.new(tenant: "other-tenant")
      other_repo.write(ns: "doc", id: "report-1", relation: "viewer", subj_ns: "user", subj_id: "eve")

      edges = repo.edges_for_object(ns: "doc", id: "report-1", relation: "viewer")

      # Should not include eve from other tenant
      expect(edges.map { |e| e[:subj_id] }).not_to include("eve")
    end
  end

  describe "#parents_of" do
    before do
      # Hierarchical structure: doc -> folder1 -> folder2
      repo.write(ns: "doc", id: "report-1", relation: "parent", subj_ns: "folder", subj_id: "q4-reports")
      repo.write(ns: "folder", id: "q4-reports", relation: "parent", subj_ns: "folder", subj_id: "finance")
    end

    it "returns immediate parent objects" do
      parents = repo.parents_of(ns: "doc", id: "report-1")

      expect(parents.length).to eq(1)
      expect(parents.first[:parent_ns]).to eq("folder")
      expect(parents.first[:parent_id]).to eq("q4-reports")
    end

    it "returns empty array when no parents exist" do
      parents = repo.parents_of(ns: "folder", id: "finance")
      expect(parents).to be_empty
    end

    it "handles multiple parents" do
      # Add second parent
      repo.write(ns: "doc", id: "report-1", relation: "parent", subj_ns: "folder", subj_id: "shared")

      parents = repo.parents_of(ns: "doc", id: "report-1")
      expect(parents.length).to eq(2)

      parent_ids = parents.map { |p| p[:parent_id] }
      expect(parent_ids).to contain_exactly("q4-reports", "shared")
    end
  end

  describe "#expand_group_members" do
    before do
      # Nested group structure:
      # alice -> eng (member)
      # bob -> eng (member)
      # charlie -> marketing (member)
      # eng -> all-staff (member)  <- nested group
      # marketing -> all-staff (member)  <- nested group

      repo.write(ns: "group", id: "eng", relation: "member", subj_ns: "user", subj_id: "alice")
      repo.write(ns: "group", id: "eng", relation: "member", subj_ns: "user", subj_id: "bob")
      repo.write(ns: "group", id: "marketing", relation: "member", subj_ns: "user", subj_id: "charlie")
      repo.write(ns: "group", id: "all-staff", relation: "member", subj_ns: "group", subj_id: "eng")
      repo.write(ns: "group", id: "all-staff", relation: "member", subj_ns: "group", subj_id: "marketing")
    end

    it "returns direct members of a group" do
      members = repo.expand_group_members(group_ns: "group", group_id: "eng")

      expect(members.length).to eq(2)
      member_ids = members.map { |m| m[:subj_id] }
      expect(member_ids).to contain_exactly("alice", "bob")
    end

    it "recursively expands nested groups" do
      members = repo.expand_group_members(group_ns: "group", group_id: "all-staff")

      expect(members.length).to eq(3)
      member_ids = members.map { |m| m[:subj_id] }
      expect(member_ids).to contain_exactly("alice", "bob", "charlie")
    end

    it "returns empty array for non-existent groups" do
      members = repo.expand_group_members(group_ns: "group", group_id: "nonexistent")
      expect(members).to be_empty
    end

    it "handles circular group references without infinite loop" do
      # Create circular reference: group-a -> group-b -> group-a
      repo.write(ns: "group", id: "group-a", relation: "member", subj_ns: "group", subj_id: "group-b")
      repo.write(ns: "group", id: "group-b", relation: "member", subj_ns: "group", subj_id: "group-a")
      repo.write(ns: "group", id: "group-a", relation: "member", subj_ns: "user", subj_id: "test-user")

      # Should not raise error or hang
      expect {
        members = repo.expand_group_members(group_ns: "group", group_id: "group-a")
        expect(members).to be_an(Array)
      }.not_to raise_error
    end
  end
end
