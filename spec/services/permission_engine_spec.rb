require "rails_helper"

RSpec.describe PermissionEngine do
  let(:repo) { RebacRepo.new(tenant: "test-tenant") }
  let(:engine) { described_class.new(repo: repo) }

  before do
    # Clean slate for each test
    RelTuple.where(tenant_id: "test-tenant").delete_all
  end

  describe "#check" do
    context "direct permissions" do
      it "grants permission for direct owner relationship" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")

        expect(engine.check("user", "alice", "owner", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "bob", "owner", "doc", "report-1")).to eq(false)
      end

      it "grants permission for direct editor relationship" do
        repo.write(subject: "doc", id: "report-1", relation: "editor", actor: "user", actor_id: "bob")

        expect(engine.check("user", "bob", "editor", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "alice", "editor", "doc", "report-1")).to eq(false)
      end

      it "grants permission for direct viewer relationship" do
        repo.write(subject: "doc", id: "report-1", relation: "viewer", actor: "user", actor_id: "charlie")

        expect(engine.check("user", "charlie", "viewer", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "alice", "viewer", "doc", "report-1")).to eq(false)
      end
    end

    context "union relations (doc: viewer = [editor, parent->viewer])" do
      it "grants viewer if user is editor (union)" do
        repo.write(subject: "doc", id: "report-1", relation: "editor", actor: "user", actor_id: "alice")

        # viewer includes editor, so alice should be able to view
        expect(engine.check("user", "alice", "viewer", "doc", "report-1")).to eq(true)
      end

      it "grants viewer if user is owner (union chain: owner -> editor -> viewer)" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")

        # owner -> editor -> viewer (union chain)
        expect(engine.check("user", "alice", "viewer", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "alice", "editor", "doc", "report-1")).to eq(true)
      end
    end

    context "group-based permissions (group#member)" do
      it "grants permission via group membership" do
        repo.write(subject: "group", id: "eng", relation: "member", actor: "user", actor_id: "alice")
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "group", actor_id: "eng", actor_rel: "member")

        # alice is member of eng, eng#member owns doc
        expect(engine.check("user", "alice", "owner", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "bob", "owner", "doc", "report-1")).to eq(false)
      end

      it "grants permission via nested group membership" do
        repo.write(subject: "group", id: "frontend", relation: "member", actor: "user", actor_id: "alice")
        repo.write(subject: "group", id: "eng", relation: "member", actor: "group", actor_id: "frontend")
        repo.write(subject: "doc", id: "report-1", relation: "viewer", actor: "group", actor_id: "eng", actor_rel: "member")

        # alice -> frontend -> eng, eng#member can view doc
        expect(engine.check("user", "alice", "viewer", "doc", "report-1")).to eq(true)
      end
    end

    context "parent inheritance (parent->relation)" do
      it "grants viewer via folder->owner" do
        repo.write(subject: "group", id: "marketing", relation: "member", actor: "user", actor_id: "alice")
        repo.write(subject: "folder", id: "Q4", relation: "owner", actor: "group", actor_id: "marketing")
        repo.write(subject: "doc", id: "123", relation: "parent", actor: "folder", actor_id: "Q4")

        # alice is in marketing, marketing owns Q4, doc 123 is in Q4
        # doc viewer = [editor, parent->viewer]
        # folder viewer = [editor, group#viewer]
        # marketing owns folder, so marketing members can view
        expect(engine.check("user", "alice", "viewer", "doc", "123")).to eq(true)
        expect(engine.check("user", "bob", "viewer", "doc", "123")).to eq(false)
      end

      it "grants editor via parent->editor" do
        repo.write(subject: "user", id: "alice", relation: "self", actor: "user", actor_id: "alice")
        repo.write(subject: "folder", id: "finance", relation: "editor", actor: "user", actor_id: "alice")
        repo.write(subject: "doc", id: "budget-2024", relation: "parent", actor: "folder", actor_id: "finance")

        # alice is editor of folder, doc inherits editor from parent
        expect(engine.check("user", "alice", "editor", "doc", "budget-2024")).to eq(true)
      end

      it "grants permission through nested parent hierarchy" do
        # folder1 <- folder2 <- folder3 <- doc
        repo.write(subject: "folder", id: "folder3", relation: "parent", actor: "folder", actor_id: "folder2")
        repo.write(subject: "folder", id: "folder2", relation: "parent", actor: "folder", actor_id: "folder1")
        repo.write(subject: "doc", id: "deep-doc", relation: "parent", actor: "folder", actor_id: "folder3")
        repo.write(subject: "folder", id: "folder1", relation: "owner", actor: "user", actor_id: "alice")

        # alice owns root folder, permission should cascade down
        expect(engine.check("user", "alice", "viewer", "doc", "deep-doc")).to eq(true)
      end
    end

    context "complex multi-hop scenarios" do
      it "resolves permission through group + parent + union" do
        # Setup:
        # - alice is member of eng group
        # - eng group owns folder "projects"
        # - doc "api-spec" has parent "projects"
        # - Check if alice can view "api-spec"

        repo.write(subject: "group", id: "eng", relation: "member", actor: "user", actor_id: "alice")
        repo.write(subject: "folder", id: "projects", relation: "owner", actor: "group", actor_id: "eng", actor_rel: "member")
        repo.write(subject: "doc", id: "api-spec", relation: "parent", actor: "folder", actor_id: "projects")

        expect(engine.check("user", "alice", "viewer", "doc", "api-spec")).to eq(true)
      end
    end

    context "depth limits" do
      it "respects max depth to prevent infinite loops" do
        # Create a very deep chain that exceeds max_depth
        # This should return false rather than hanging

        stub_const("#{described_class}::MAX_DEPTH", 3)

        # Create chain: folder1 -> folder2 -> folder3 -> folder4 -> doc
        repo.write(subject: "folder", id: "folder4", relation: "parent", actor: "folder", actor_id: "folder3")
        repo.write(subject: "folder", id: "folder3", relation: "parent", actor: "folder", actor_id: "folder2")
        repo.write(subject: "folder", id: "folder2", relation: "parent", actor: "folder", actor_id: "folder1")
        repo.write(subject: "doc", id: "deep-doc", relation: "parent", actor: "folder", actor_id: "folder4")
        repo.write(subject: "folder", id: "folder1", relation: "owner", actor: "user", actor_id: "alice")

        # With max_depth=3, this should fail (too deep)
        expect(engine.check("user", "alice", "viewer", "doc", "deep-doc")).to eq(false)
      end
    end

    context "negative cases" do
      it "returns false for non-existent object" do
        expect(engine.check("user", "alice", "viewer", "doc", "nonexistent")).to eq(false)
      end

      it "returns false for non-existent subject" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")

        expect(engine.check("user", "nonexistent", "owner", "doc", "report-1")).to eq(false)
      end

      it "returns false for non-existent relation" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")

        expect(engine.check("user", "alice", "deleter", "doc", "report-1")).to eq(false)
      end
    end
  end

  describe "#explain" do
    context "direct permissions" do
      it "returns simple path for direct relationship" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")

        path = engine.explain("user", "alice", "owner", "doc", "report-1")

        expect(path).to be_present
        expect(path).to include(a_hash_including(
          relation: "owner",
          subject: "doc",
          id: "report-1"
        ))
      end
    end

    context "union relations" do
      it "explains path through union relation (editor -> viewer)" do
        repo.write(subject: "doc", id: "report-1", relation: "editor", actor: "user", actor_id: "alice")

        path = engine.explain("user", "alice", "viewer", "doc", "report-1")

        expect(path).to be_present
        # Path should show: user alice -> doc:report-1#editor -> doc:report-1#viewer
      end
    end

    context "group membership" do
      it "explains path through group membership" do
        repo.write(subject: "group", id: "eng", relation: "member", actor: "user", actor_id: "alice")
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "group", actor_id: "eng", actor_rel: "member")

        path = engine.explain("user", "alice", "owner", "doc", "report-1")

        expect(path).to be_present
        # Should show: user alice -> group:eng#member -> doc:report-1#owner
      end
    end

    context "parent inheritance" do
      it "explains path through parent->relation" do
        repo.write(subject: "folder", id: "finance", relation: "owner", actor: "user", actor_id: "alice")
        repo.write(subject: "doc", id: "budget", relation: "parent", actor: "folder", actor_id: "finance")

        path = engine.explain("user", "alice", "viewer", "doc", "budget")

        expect(path).to be_present
        # Should show inheritance through parent folder
      end
    end

    context "negative cases" do
      it "returns nil when permission is denied" do
        expect(engine.explain("user", "alice", "owner", "doc", "nonexistent")).to be_nil
      end

      it "returns nil for unauthorized access" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "bob")

        expect(engine.explain("user", "alice", "owner", "doc", "report-1")).to be_nil
      end
    end
  end
end
