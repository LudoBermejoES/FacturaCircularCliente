Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication routes
  get    'login',  to: 'sessions#new',     as: :login
  post   'login',  to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy', as: :logout
  
  # Company selection/switching
  get  'select_company', to: 'companies#select', as: :select_company
  post 'switch_company', to: 'companies#switch', as: :switch_company
  
  # Dashboard
  get 'dashboard', to: 'dashboard#index', as: :dashboard
  
  # Companies
  resources :companies do
    resources :addresses, only: [:create, :update, :destroy]
    
    # Company contacts management
    resources :company_contacts, except: [:show] do
      member do
        post :activate
        post :deactivate
      end

      # Address management for contacts
      resources :addresses, controller: 'company_contact_addresses' do
        member do
          post :set_default
        end
      end
    end
    
    # User management within companies
    resources :users, controller: 'user_companies', only: [:index, :new, :create, :edit, :update, :destroy]
    
    # Invoice Series management
    resources :invoice_series do
      member do
        post :activate
        post :deactivate
        get :statistics
        get :compliance
        post :rollover
      end
    end
  end
  
  # Invoices
  resources :invoices do
    member do
      post :freeze
      post :send_email
      get :pdf, action: :download_pdf
      get :facturae, action: :download_facturae
    end
    
    # Workflow management
    resource :workflow, only: [:show] do
      post :transition
    end
  end
  
  # Bulk workflow operations
  post 'invoices/bulk_transition', to: 'workflows#bulk_transition', as: :bulk_invoice_transition

  # Workflow Definitions Management
  resources :workflow_definitions do
    resources :workflow_states, only: [:index, :show, :new, :create, :edit, :update, :destroy]
    resources :workflow_transitions, only: [:index, :show, :new, :create, :edit, :update, :destroy]
  end

  # Tax Management
  resources :tax_rates
  resources :tax_calculations, only: [:new, :create, :show] do
    collection do
      post :validate
      post :invoice
      post :recalculate
    end
  end

  # Products Management
  resources :products do
    collection do
      get :search
    end
    member do
      post :activate
      post :deactivate
      post :duplicate
    end
  end
  
  # Invoice Numbering API endpoints (for AJAX calls)
  namespace :api do
    namespace :v1 do
      get 'invoice_numbering/next_available', to: 'invoice_numbering#next_available'
      get 'companies/:company_id/contacts', to: 'company_contacts#index'
    end
  end
  
  # Root path
  root "dashboard#index"
end
