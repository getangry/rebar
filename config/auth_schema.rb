# Rebar Authorization Schema (Ruby DSL)
# This file defines multiple named schemas for different use cases

# Default Schema - Document & Folder Management
AuthSchema.schema :default, purpose: "Document and folder management with hierarchical permissions" do
  # User type - basic entity with no relations
  type :user

  # Group type - supports membership
  type :group do
    relation :member, allow: [:user, :group]
  end

  # Folder type - hierarchical container
  type :folder do
    relation :parent, allow: [:folder]
    relation :owner, allow: [:user, :group, "parent->owner"]

    # Relations with inheritance
    relation :editor, allow: [:owner, "parent->editor"]
    relation :viewer, allow: [:editor, "parent->viewer"]

    # Computed permissions using custom logic
    permission :can_delete do |context|
      # Only owners can delete folders
      context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
    end

    permission :can_move do |context|
      # Owners or parent owners can move
      is_owner = context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
      if is_owner
        true
      else
        # Check if user owns parent folder
        parents = context.repo.parents_of(subject: context.subject, id: context.subject_id)
        parents.any? do |parent|
          context.check(context.actor, context.actor_id, :owner, parent["subject"], parent["id"])
        end
      end
    end

    permission :can_share do |context|
      # Editors and above can share
      context.check(context.actor, context.actor_id, :editor, context.subject, context.subject_id)
    end
  end

  # Document type - inherits from parent folder
  type :doc do
    relation :parent, allow: [:folder]
    relation :owner, allow: [:user, :group]

    # Relations with parent inheritance
    relation :editor, allow: [:owner, "parent->editor"]
    relation :viewer, allow: [:editor, "parent->viewer"]

    # Computed permissions
    permission :can_delete do |context|
      # Only the document owner can delete (not parent owners)
      context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
    end

    permission :can_edit do |context|
      # Editors and above can edit
      context.check(context.actor, context.actor_id, :editor, context.subject, context.subject_id)
    end

    permission :can_archive do |context|
      # Document owner OR folder owner can archive
      is_doc_owner = context.check(context.actor, context.actor_id, :owner, context.subject, context.subject_id)
      if is_doc_owner
        true
      else
        # Check if user owns parent folder
        parents = context.repo.parents_of(subject: context.subject, id: context.subject_id)
        parents.any? do |parent|
          context.check(context.actor, context.actor_id, :owner, parent["subject"], parent["id"])
        end
      end
    end

    permission :can_view do |context|
      # Use relation-based viewer permission
      context.check(context.actor, context.actor_id, :viewer, context.subject, context.subject_id)
    end
  end

  # Document (aliased as 'document' for data generation)
  type :document do
    relation :parent, allow: [:folder]
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner, "parent->editor"]
    relation :viewer, allow: [:editor, "parent->viewer"]
  end

  # Comment - generic comment entity
  type :comment do
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner]
    relation :viewer, allow: [:editor]
  end

  # Wiki Page
  type :wiki_page do
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner]
    relation :viewer, allow: [:editor]
  end
end

# Organization Schema - Organizational Hierarchy
AuthSchema.schema :organization, purpose: "Organization, department, and team hierarchy management" do
  type :user

  type :group do
    relation :member, allow: [:user, :group]
  end

  # Organization - top-level entity
  type :organization do
    relation :owner, allow: [:user, :group]
    relation :admin, allow: [:owner]
    relation :member, allow: [:admin]
    relation :viewer, allow: [:member]
  end

  # Department - belongs to organization
  type :department do
    relation :parent, allow: [:organization]
    relation :owner, allow: [:user, :group, "parent->owner"]
    relation :admin, allow: [:owner, "parent->admin"]
    relation :member, allow: [:admin]
  end

  # Team - belongs to department
  type :team do
    relation :parent, allow: [:department]
    relation :owner, allow: [:user, :group, "parent->owner"]
    relation :admin, allow: [:owner, "parent->admin"]
    relation :member, allow: [:admin]
  end
end

# Workspace Schema - Project & Repository Management
AuthSchema.schema :workspace, purpose: "Workspace, project, and repository management for development teams" do
  type :user

  type :group do
    relation :member, allow: [:user, :group]
  end

  # Workspace - container for projects
  type :workspace do
    relation :owner, allow: [:user, :group]
    relation :admin, allow: [:owner]
    relation :member, allow: [:admin]
    relation :viewer, allow: [:member]
  end

  # Project - belongs to workspace
  type :project do
    relation :parent, allow: [:workspace]
    relation :owner, allow: [:user, :group, "parent->owner"]
    relation :admin, allow: [:owner, "parent->admin"]
    relation :maintainer, allow: [:admin]
    relation :contributor, allow: [:maintainer]
    relation :viewer, allow: [:contributor, "parent->viewer"]
  end

  # Repository - code repository
  type :repository do
    relation :owner, allow: [:user, :group]
    relation :admin, allow: [:owner]
    relation :maintainer, allow: [:admin]
    relation :contributor, allow: [:maintainer]
    relation :viewer, allow: [:contributor]
  end

  # Issue - belongs to repository
  type :issue do
    relation :parent, allow: [:repository]
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner, "parent->contributor"]
    relation :viewer, allow: [:editor, "parent->viewer"]
  end

  # Pull Request - belongs to repository
  type :pull_request do
    relation :parent, allow: [:repository]
    relation :owner, allow: [:user, :group]
    relation :reviewer, allow: [:owner, "parent->maintainer"]
    relation :viewer, allow: [:reviewer, "parent->viewer"]
  end
end

# Data Analytics Schema - Dashboards, Reports, and Datasets
AuthSchema.schema :analytics, purpose: "Data analytics resources including dashboards, reports, and datasets" do
  type :user

  type :group do
    relation :member, allow: [:user, :group]
  end

  # Dashboard
  type :dashboard do
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner]
    relation :viewer, allow: [:editor]
  end

  # Report
  type :report do
    relation :owner, allow: [:user, :group]
    relation :viewer, allow: [:owner]
  end

  # Dataset
  type :dataset do
    relation :owner, allow: [:user, :group]
    relation :editor, allow: [:owner]
    relation :viewer, allow: [:editor]
  end
end

# DevOps Schema - Infrastructure and Operations
AuthSchema.schema :devops, purpose: "DevOps resources including pipelines, secrets, API keys, and integrations" do
  type :user

  type :group do
    relation :member, allow: [:user, :group]
  end

  # Pipeline (CI/CD pipeline)
  type :pipeline do
    relation :owner, allow: [:user, :group]
    relation :admin, allow: [:owner]
    relation :editor, allow: [:admin]
    relation :viewer, allow: [:editor]
  end

  # Secret (credentials, API keys stored securely)
  type :secret do
    relation :owner, allow: [:user, :group]
    relation :admin, allow: [:owner]
    relation :viewer, allow: [:admin]
  end

  # API Key
  type :api_key do
    relation :owner, allow: [:user, :group]
    relation :admin, allow: [:owner]
  end

  # Webhook
  type :webhook do
    relation :owner, allow: [:user, :group]
    relation :admin, allow: [:owner]
  end

  # Integration (third-party integrations)
  type :integration do
    relation :owner, allow: [:user, :group]
    relation :admin, allow: [:owner]
    relation :viewer, allow: [:admin]
  end
end
