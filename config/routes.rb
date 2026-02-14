Rails.application.routes.draw do
  # MCP Streamable HTTP endpoint (official mcp gem)
  post "/mcp", to: "mcp#handle"

  # MCP discovery (/.well-known/mcp)
  get "/.well-known/mcp", to: "mcp_discovery#show"

  # OAuth/OIDC discovery — rmcp probes all of these path variants.
  # Returning metadata prevents "No authorization support detected" errors.
  get "/.well-known/oauth-authorization-server", to: "mcp_discovery#oauth_metadata"
  get "/.well-known/oauth-authorization-server/mcp", to: "mcp_discovery#oauth_metadata"
  get "/.well-known/openid-configuration/mcp", to: "mcp_discovery#oauth_metadata"
  get "/mcp/.well-known/openid-configuration", to: "mcp_discovery#oauth_metadata"
  get "/.well-known/oauth-protected-resource", to: "mcp_discovery#prm"
  get "/.well-known/oauth-protected-resource/mcp", to: "mcp_discovery#prm"
  get "/mcp/.well-known/oauth-protected-resource", to: "mcp_discovery#prm"

  # OAuth endpoints namespaced under /mcp to avoid collision with OmniAuth/Devise.
  # These reject all requests with a clear "use Bearer token" message.
  get "/mcp/oauth/authorize", to: "mcp_discovery#oauth_authorize"
  post "/mcp/oauth/token", to: "mcp_discovery#oauth_token"

  resources :reports do
    member do
      post :submit
    end
  end
  resources :attachments, only: [ :create, :destroy ] do
    member do
      get :download
    end
  end
  resources :notes, only: [ :create, :edit, :update, :destroy ]
  resources :links, only: [ :create, :edit, :update, :destroy ]
  resources :teams
  resources :organizations
  resources :tasks do
    member do
      patch :update_state
      get :history
      get :integration_tab
      patch :move_to_today
      patch :move_to_backlog
    end
    collection do
      patch :reorder_today
      patch :reorder_backlog
    end
  end
  resources :scopes do
    member do
      patch :reorder_tasks
    end
    collection do
      post :hillchart_update
    end
  end
  resources :projects do
    member do
      get :analytics_by_user
      get :cycle_time
      get :risk_history
      patch :update_risk_state
      patch :reorder_scopes
    end
  end
  post "subscribables/:id/subscribe", to: "subscribables#create_subscription", as: :create_subscription
  delete "subscriptions/:id", to: "subscriptions#destroy", as: :destroy_subscription
  devise_for :users,
    controllers: {
      omniauth_callbacks: "users/omniauth_callbacks",
      registrations: "users/registrations",
      confirmations: "users/confirmations"
    }

  resource :profile, only: [ :show ], controller: "profiles"

  resources :api_tokens, only: [ :create, :destroy ]

  # Mount optional engines for feature integration
  # mount TudlaHubstaff::Engine => "/tudla_hubstaff"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "dashboard", to: "pages#dashboard", as: :user_root

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  root "pages#home"
end
