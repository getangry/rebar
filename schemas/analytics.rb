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
