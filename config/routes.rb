Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes (versioned for future compatibility)
  namespace :api do
    # Authorization API
    post "auth/check", to: "auth#check"
    post "auth/explain", to: "auth#explain"

    # Relationship Tuples API
    post "tuples", to: "tuples#create"
    delete "tuples", to: "tuples#destroy"
    post "tuples/batch", to: "tuples#batch_create"
    delete "tuples/batch", to: "tuples#batch_destroy"

    # Audit Logs API
    get "audit_logs", to: "audit_logs#index"
    get "audit_logs/stats", to: "audit_logs#stats"
    get "audit_logs/tuple_history", to: "audit_logs#tuple_history"
    get "audit_logs/:id", to: "audit_logs#show"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
