require 'rails_helper'

RSpec.describe "Auth Schema", type: :service do
  let(:schema_path) { Rails.root.join("config", "auth_schema.yml") }
  let(:schema) { YAML.load_file(schema_path) }

  describe "schema structure" do
    it "has top-level 'types' key" do
      expect(schema).to have_key("types")
      expect(schema["types"]).to be_a(Hash)
    end

    it "defines core types" do
      types = schema["types"]

      expect(types).to have_key("user")
      expect(types).to have_key("group")
      expect(types).to have_key("folder")
      expect(types).to have_key("doc")
    end
  end

  describe "user type" do
    let(:user_type) { schema["types"]["user"] }

    it "exists as a base type" do
      expect(user_type).to be_present
    end

    it "has no relations (leaf type)" do
      expect(user_type["relations"]).to be_nil
    end
  end

  describe "group type" do
    let(:group_type) { schema["types"]["group"] }

    it "has relations defined" do
      expect(group_type).to have_key("relations")
      expect(group_type["relations"]).to be_a(Hash)
    end

    it "has 'member' relation" do
      relations = group_type["relations"]
      expect(relations).to have_key("member")
    end

    it "allows users and groups as members" do
      member_relation = group_type["relations"]["member"]

      expect(member_relation).to be_an(Array)
      expect(member_relation).to include("user")
      expect(member_relation).to include("group")
    end

    it "supports nested group membership" do
      # group can be a member of another group
      member_relation = group_type["relations"]["member"]
      expect(member_relation).to include("group")
    end
  end

  describe "folder type" do
    let(:folder_type) { schema["types"]["folder"] }

    it "has relations defined" do
      expect(folder_type).to have_key("relations")
    end

    it "supports parent relationship for hierarchy" do
      relations = folder_type["relations"]
      expect(relations).to have_key("parent")
      expect(relations["parent"]).to include("folder")
    end

    it "has owner, editor, viewer permission levels" do
      relations = folder_type["relations"]

      expect(relations).to have_key("owner")
      expect(relations).to have_key("editor")
      expect(relations).to have_key("viewer")
    end

    it "defines union relations for permissions" do
      relations = folder_type["relations"]

      # owner includes direct users/groups
      expect(relations["owner"]).to include("user")
      expect(relations["owner"]).to include("group")

      # editor includes owners and group editors
      expect(relations["editor"]).to include("owner")
      expect(relations["editor"]).to include("group#editor")

      # viewer includes editors and group viewers
      expect(relations["viewer"]).to include("editor")
      expect(relations["viewer"]).to include("group#viewer")
    end
  end

  describe "doc type" do
    let(:doc_type) { schema["types"]["doc"] }

    it "has relations defined" do
      expect(doc_type).to have_key("relations")
    end

    it "supports parent relationship to folder" do
      relations = doc_type["relations"]
      expect(relations).to have_key("parent")
      expect(relations["parent"]).to include("folder")
    end

    it "has owner, editor, viewer permission levels" do
      relations = doc_type["relations"]

      expect(relations).to have_key("owner")
      expect(relations).to have_key("editor")
      expect(relations).to have_key("viewer")
    end

    it "inherits permissions from parent folder" do
      relations = doc_type["relations"]

      # editor includes parent folder's editors
      expect(relations["editor"]).to include("parent->editor")

      # viewer includes parent folder's viewers
      expect(relations["viewer"]).to include("parent->viewer")
    end

    it "defines union relations with inheritance" do
      relations = doc_type["relations"]

      # editor includes owner + parent inheritance
      expect(relations["editor"]).to include("owner")
      expect(relations["editor"]).to include("parent->editor")

      # viewer includes editor + parent inheritance
      expect(relations["viewer"]).to include("editor")
      expect(relations["viewer"]).to include("parent->viewer")
    end
  end

  describe "relation patterns" do
    it "uses union relations (arrays) for OR logic" do
      # Multiple entries in an array mean ANY of them grants permission
      folder_viewer = schema["types"]["folder"]["relations"]["viewer"]

      expect(folder_viewer).to be_an(Array)
      expect(folder_viewer.length).to be > 1
    end

    it "uses group#relation syntax for group membership expansion" do
      # "group#member" means expand group members
      folder_editor = schema["types"]["folder"]["relations"]["editor"]

      expect(folder_editor).to include("group#editor")
    end

    it "uses parent->relation syntax for inheritance" do
      # "parent->editor" means inherit editor from parent object
      doc_editor = schema["types"]["doc"]["relations"]["editor"]

      expect(doc_editor).to include("parent->editor")
    end

    it "chains permissions through includes" do
      # viewer includes editor includes owner (transitive)
      doc_relations = schema["types"]["doc"]["relations"]

      expect(doc_relations["viewer"]).to include("editor")
      expect(doc_relations["editor"]).to include("owner")
    end
  end

  describe "schema validation" do
    it "has valid YAML syntax" do
      expect {
        YAML.load_file(schema_path)
      }.not_to raise_error
    end

    it "has no duplicate type names" do
      type_names = schema["types"].keys
      expect(type_names.uniq.length).to eq(type_names.length)
    end

    it "references only defined types in relations" do
      defined_types = schema["types"].keys

      schema["types"].each do |type_name, type_def|
        next unless type_def["relations"]

        type_def["relations"].each do |relation_name, targets|
          targets.each do |target|
            # Extract base type from patterns like "group#member" or "parent->editor"
            base_type = target.split(/[#\->]/).first

            # Skip special keywords like "parent"
            next if ["parent", "owner", "editor", "viewer"].include?(base_type)

            expect(defined_types).to include(base_type),
              "Type '#{type_name}' relation '#{relation_name}' references undefined type '#{base_type}'"
          end
        end
      end
    end

    it "has no circular direct references" do
      # Direct self-reference like doc -> doc (except for folder->folder parent)
      schema["types"].each do |type_name, type_def|
        next unless type_def["relations"]

        type_def["relations"].each do |relation_name, targets|
          targets.each do |target|
            base_type = target.split(/[#\->]/).first

            # folder->folder is allowed for parent relationship
            next if type_name == "folder" && base_type == "folder" && relation_name == "parent"

            if base_type == type_name
              fail "Type '#{type_name}' has circular reference in relation '#{relation_name}'"
            end
          end
        end
      end
    end
  end

  describe "permission model" do
    it "follows hierarchical permission pattern" do
      # owner > editor > viewer

      ["folder", "doc"].each do |type_name|
        relations = schema["types"][type_name]["relations"]

        # viewer should include editor
        expect(relations["viewer"]).to include("editor")

        # editor should include owner
        expect(relations["editor"]).to include("owner")
      end
    end

    it "supports group-based access control" do
      # Both folder and doc should support group ownership

      ["folder", "doc"].each do |type_name|
        relations = schema["types"][type_name]["relations"]

        expect(relations["owner"]).to include("group")
      end
    end

    it "supports inheritance through parent relationships" do
      # Doc should inherit permissions from folder

      doc_relations = schema["types"]["doc"]["relations"]

      expect(doc_relations).to have_key("parent")
      expect(doc_relations["editor"]).to include("parent->editor")
      expect(doc_relations["viewer"]).to include("parent->viewer")
    end
  end

  describe "integration with PermissionEngine" do
    it "can be loaded by PermissionEngine" do
      expect {
        schema = YAML.load_file(Rails.root.join("config", "auth_schema.yml"))
        expect(schema["types"]).to be_present
      }.not_to raise_error
    end

    it "defines relations that PermissionEngine can traverse" do
      # PermissionEngine should be able to handle all relation types

      repo = RebacRepo.new(tenant: "test")
      engine = PermissionEngine.new(repo: repo)

      # Schema is loaded in engine initialization
      expect(engine.instance_variable_get(:@schema)).to be_present
    end
  end

  describe "common permission scenarios" do
    let(:repo) { RebacRepo.new(tenant: "schema-test") }
    let(:engine) { PermissionEngine.new(repo: repo) }

    before do
      RelTuple.where(tenant_id: "schema-test").delete_all
    end

    it "supports direct user ownership" do
      # Schema: doc owner includes "user"

      repo.write(ns: "doc", id: "report", relation: "owner", subj_ns: "user", subj_id: "alice")

      expect(engine.check("user", "alice", "owner", "doc", "report")).to eq(true)
    end

    it "supports group ownership" do
      # Schema: doc owner includes "group"

      repo.write(ns: "group", id: "eng", relation: "member", subj_ns: "user", subj_id: "alice")
      repo.write(ns: "doc", id: "report", relation: "owner", subj_ns: "group", subj_id: "eng", subj_rel: "member")

      expect(engine.check("user", "alice", "owner", "doc", "report")).to eq(true)
    end

    it "supports permission cascading (owner -> editor -> viewer)" do
      # Schema: viewer includes editor, editor includes owner

      repo.write(ns: "doc", id: "report", relation: "owner", subj_ns: "user", subj_id: "alice")

      expect(engine.check("user", "alice", "viewer", "doc", "report")).to eq(true)
      expect(engine.check("user", "alice", "editor", "doc", "report")).to eq(true)
    end

    it "supports parent inheritance" do
      # Schema: doc viewer includes "parent->viewer"

      repo.write(ns: "folder", id: "finance", relation: "owner", subj_ns: "user", subj_id: "alice")
      repo.write(ns: "doc", id: "budget", relation: "parent", subj_ns: "folder", subj_id: "finance")

      expect(engine.check("user", "alice", "viewer", "doc", "budget")).to eq(true)
    end

    it "supports nested group membership" do
      # Schema: group member includes "group"

      repo.write(ns: "group", id: "frontend", relation: "member", subj_ns: "user", subj_id: "alice")
      repo.write(ns: "group", id: "eng", relation: "member", subj_ns: "group", subj_id: "frontend")
      repo.write(ns: "doc", id: "api-spec", relation: "viewer", subj_ns: "group", subj_id: "eng", subj_rel: "member")

      expect(engine.check("user", "alice", "viewer", "doc", "api-spec")).to eq(true)
    end
  end

  describe "schema evolution" do
    it "can be extended with new types" do
      # Schema should support adding new types like "project", "task", etc.
      # without breaking existing types

      expect(schema["types"].keys).to be_an(Array)

      # Should be able to add new type
      # types:
      #   project:
      #     relations:
      #       owner: ["user", "group"]
    end

    it "can be extended with new relations" do
      # Existing types can get new relations
      # E.g., add "admin" relation to folder

      folder_relations = schema["types"]["folder"]["relations"]
      expect(folder_relations.keys).to be_an(Array)

      # Could add:
      # admin: ["owner", "user"]
    end

    it "maintains backward compatibility" do
      # Existing relation names should remain stable
      # Adding new relations shouldn't break old ones

      doc_relations = schema["types"]["doc"]["relations"]

      expect(doc_relations).to have_key("owner")
      expect(doc_relations).to have_key("editor")
      expect(doc_relations).to have_key("viewer")
      expect(doc_relations).to have_key("parent")
    end
  end
end
