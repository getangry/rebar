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
