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
