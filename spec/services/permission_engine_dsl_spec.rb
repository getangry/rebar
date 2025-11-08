require "rails_helper"
require_relative "../../lib/auth_schema"

RSpec.describe PermissionEngine, "with Ruby DSL" do
  let(:repo) { RebacRepo.new(tenant: "test-tenant") }

  # Define schema inline for testing
  let(:schema) do
    AuthSchema.define do
      type :user

      type :group do
        relation :member, allow: [:user, :group]
      end

      type :folder do
        relation :parent, allow: [:folder]
        relation :owner, allow: [:user, :group, "parent->owner"]
        relation :editor, allow: [:owner, "parent->editor"]
        relation :viewer, allow: [:editor, "parent->viewer"]

        # Only owners can delete folders
        permission :can_delete do |context|
          context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
        end

        # Owners or parent owners can move
        permission :can_move do |context|
          is_owner = context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
          if is_owner
            true
          else
            parents = context.repo.parents_of(subject: context.subject, id: context.subject_id)
            parents.any? do |parent|
              context.check(context.actor, context.actor_id, :owner, parent["subject"], parent["id"])
            end
          end
        end
      end

      type :doc do
        relation :parent, allow: [:folder]
        relation :owner, allow: [:user, :group]
        relation :editor, allow: [:owner, "parent->editor"]
        relation :viewer, allow: [:editor, "parent->viewer"]

        # Only document owner can delete (not parent owners)
        permission :can_delete do |context|
          context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
        end

        # Document owner OR parent folder owner can archive
        permission :can_archive do |context|
          is_doc_owner = context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
          if is_doc_owner
            true
          else
            parents = context.repo.parents_of(subject: context.subject, id: context.subject_id)
            parents.any? do |parent|
              context.check(context.actor, context.actor_id, :owner, parent["subject"], parent["id"])
            end
          end
        end
      end
    end
  end

  let(:engine) { described_class.new(schema: schema, repo: repo) }

  before do
    RelTuple.where(tenant_id: "test-tenant").delete_all
  end

  describe "computed permissions" do
    context "folder can_delete" do
      it "allows owner to delete" do
        repo.write(subject: "folder", id: "reports", relation: "owner", actor: "user", actor_id: "alice")

        expect(engine.check("user", "alice", "can_delete", "folder", "reports")).to eq(true)
      end

      it "denies non-owner from deleting" do
        repo.write(subject: "folder", id: "reports", relation: "owner", actor: "user", actor_id: "alice")
        repo.write(subject: "folder", id: "reports", relation: "editor", actor: "user", actor_id: "bob")

        expect(engine.check("user", "bob", "can_delete", "folder", "reports")).to eq(false)
      end

      it "denies even editors from deleting" do
        repo.write(subject: "folder", id: "reports", relation: "editor", actor: "user", actor_id: "alice")

        expect(engine.check("user", "alice", "can_delete", "folder", "reports")).to eq(false)
      end
    end

    context "folder can_move" do
      it "allows owner to move their folder" do
        repo.write(subject: "folder", id: "child", relation: "owner", actor: "user", actor_id: "alice")

        expect(engine.check("user", "alice", "can_move", "folder", "child")).to eq(true)
      end

      it "allows parent folder owner to move child folder" do
        repo.write(subject: "folder", id: "parent", relation: "owner", actor: "user", actor_id: "alice")
        repo.write(subject: "folder", id: "child", relation: "parent", actor: "folder", actor_id: "parent")
        repo.write(subject: "folder", id: "child", relation: "owner", actor: "user", actor_id: "bob")

        # Alice owns parent, should be able to move child folder
        expect(engine.check("user", "alice", "can_move", "folder", "child")).to eq(true)
        # Bob owns child directly
        expect(engine.check("user", "bob", "can_move", "folder", "child")).to eq(true)
      end

      it "denies non-owners from moving" do
        repo.write(subject: "folder", id: "reports", relation: "owner", actor: "user", actor_id: "alice")
        repo.write(subject: "folder", id: "reports", relation: "viewer", actor: "user", actor_id: "charlie")

        expect(engine.check("user", "charlie", "can_move", "folder", "reports")).to eq(false)
      end
    end

    context "document can_delete" do
      it "allows document owner to delete" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")

        expect(engine.check("user", "alice", "can_delete", "doc", "report-1")).to eq(true)
      end

      it "denies parent folder owner from deleting document" do
        repo.write(subject: "folder", id: "reports", relation: "owner", actor: "user", actor_id: "alice")
        repo.write(subject: "doc", id: "report-1", relation: "parent", actor: "folder", actor_id: "reports")
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "bob")

        # Alice owns the parent folder but NOT the document
        expect(engine.check("user", "alice", "can_delete", "doc", "report-1")).to eq(false)
        # Bob owns the document directly
        expect(engine.check("user", "bob", "can_delete", "doc", "report-1")).to eq(true)
      end
    end

    context "document can_archive" do
      it "allows document owner to archive" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")

        expect(engine.check("user", "alice", "can_archive", "doc", "report-1")).to eq(true)
      end

      it "allows parent folder owner to archive document" do
        repo.write(subject: "folder", id: "reports", relation: "owner", actor: "user", actor_id: "alice")
        repo.write(subject: "doc", id: "report-1", relation: "parent", actor: "folder", actor_id: "reports")
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "bob")

        # Both Alice (parent owner) and Bob (doc owner) can archive
        expect(engine.check("user", "alice", "can_archive", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "bob", "can_archive", "doc", "report-1")).to eq(true)
      end

      it "denies non-owners from archiving" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")
        repo.write(subject: "doc", id: "report-1", relation: "editor", actor: "user", actor_id: "bob")

        expect(engine.check("user", "bob", "can_archive", "doc", "report-1")).to eq(false)
      end
    end

    context "combining computed and relation-based permissions" do
      it "still supports relation-based checks for viewer" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")
        repo.write(subject: "doc", id: "report-1", relation: "viewer", actor: "user", actor_id: "bob")

        # Alice can view (owner -> editor -> viewer)
        expect(engine.check("user", "alice", "viewer", "doc", "report-1")).to eq(true)
        # Bob can view (direct viewer)
        expect(engine.check("user", "bob", "viewer", "doc", "report-1")).to eq(true)
      end

      it "allows checking both permission types on same resource" do
        repo.write(subject: "doc", id: "report-1", relation: "owner", actor: "user", actor_id: "alice")

        # Relation-based
        expect(engine.check("user", "alice", "viewer", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "alice", "editor", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "alice", "owner", "doc", "report-1")).to eq(true)

        # Computed
        expect(engine.check("user", "alice", "can_delete", "doc", "report-1")).to eq(true)
        expect(engine.check("user", "alice", "can_archive", "doc", "report-1")).to eq(true)
      end
    end

    context "complex scenario with groups" do
      it "evaluates computed permissions with group membership" do
        # Setup: alice is in eng group, eng group owns folder
        repo.write(subject: "group", id: "eng", relation: "member", actor: "user", actor_id: "alice")
        repo.write(subject: "folder", id: "projects", relation: "owner", actor: "group", actor_id: "eng", actor_rel: "member")

        # Alice should be able to delete the folder (she's an owner via group)
        expect(engine.check("user", "alice", "can_delete", "folder", "projects")).to eq(true)
      end

      it "evaluates nested parent permissions with groups" do
        # alice -> eng group -> owns parent folder -> child folder -> document
        repo.write(subject: "group", id: "eng", relation: "member", actor: "user", actor_id: "alice")
        repo.write(subject: "folder", id: "parent", relation: "owner", actor: "group", actor_id: "eng", actor_rel: "member")
        repo.write(subject: "folder", id: "child", relation: "parent", actor: "folder", actor_id: "parent")
        repo.write(subject: "doc", id: "doc-1", relation: "parent", actor: "folder", actor_id: "child")

        # Alice owns parent folder, should be able to move child folder
        expect(engine.check("user", "alice", "can_move", "folder", "child")).to eq(true)

        # Alice owns grandparent folder, should be able to archive doc (via parent)
        expect(engine.check("user", "alice", "can_archive", "doc", "doc-1")).to eq(true)

        # But alice should NOT be able to delete the doc (not the direct owner)
        expect(engine.check("user", "alice", "can_delete", "doc", "doc-1")).to eq(false)
      end
    end
  end

  describe "backward compatibility with relations" do
    it "still supports all relation-based checks" do
      repo.write(subject: "folder", id: "reports", relation: "owner", actor: "user", actor_id: "alice")
      repo.write(subject: "doc", id: "budget", relation: "parent", actor: "folder", actor_id: "reports")

      # Relation-based checks still work
      expect(engine.check("user", "alice", "owner", "folder", "reports")).to eq(true)
      expect(engine.check("user", "alice", "editor", "folder", "reports")).to eq(true)
      expect(engine.check("user", "alice", "viewer", "folder", "reports")).to eq(true)

      # Parent inheritance still works
      expect(engine.check("user", "alice", "viewer", "doc", "budget")).to eq(true)
    end
  end
end
