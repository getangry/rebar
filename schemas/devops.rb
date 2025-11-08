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
