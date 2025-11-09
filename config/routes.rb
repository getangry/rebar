Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api/openapi'
  mount Rswag::Api::Engine => '/api/openapi'
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

    # Schema API
    get "schema", to: "schema#index"
    get "schema/graph", to: "schema#graph"
    get "schema/entities", to: "schema#entities"
    get "schema/relationships/:entity_id", to: "schema#relationships"

    # Schemas API (multi-schema support)
    get "schemas", to: "schemas#index"
    get "schemas/:name", to: "schemas#show"

    # Actors API
    get "actors/:actor_type/:actor_id/permissions", to: "actors#permissions"
    get "actors/:actor_type/:actor_id/groups", to: "actors#groups"

    # Services API
    resources :services, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :regenerate_key
        post :activate
        post :deactivate
        post 'subjects', to: 'services#add_subject'
        delete 'subjects/:subject', to: 'services#remove_subject'
        post 'relations', to: 'services#add_relation'
        delete 'relations/:relation', to: 'services#remove_relation'
        post 'schemas', to: 'services#add_schema'
        delete 'schemas/:schema', to: 'services#remove_schema'
        post 'api_keys', to: 'services#create_api_key'
        delete 'api_keys/:api_key_id', to: 'services#revoke_api_key'
      end
    end

    # Analytics API
    get "analytics/metrics", to: "analytics#metrics"
    get "analytics/top_permissions", to: "analytics#top_permissions"
    get "analytics/failed_attempts", to: "analytics#failed_attempts"
    get "analytics/service_usage", to: "analytics#service_usage"
    get "analytics/api_key_usage", to: "analytics#api_key_usage"
    get "analytics/time_series", to: "analytics#time_series"

    # Attributes API
    # Entity attributes
    get "attributes/:entity_type/:subject_id", to: "attributes#show"
    get "attributes/:entity_type/:subject_id/history", to: "attributes#history"
    post "attributes", to: "attributes#create"
    delete "attributes/:entity_type/:subject_id", to: "attributes#destroy"

    # Attribute schemas
    get "attributes/schemas", to: "attributes#schemas"
    post "attributes/schemas", to: "attributes#create_schema"

    # Relationship attributes
    get "attributes/relationships/:tuple_id", to: "attributes#show_relationship"
    post "attributes/relationships", to: "attributes#create_relationship"
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
