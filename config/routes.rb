Rails.application.routes.draw do

  mount ActionCable.server => '/cable'
  # Letter opener routes (development only)
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
  
  # Sidekiq Web UI (production only, with authentication)
  if Rails.env.production?
    require 'sidekiq/web'
    mount Sidekiq::Web => '/sidekiq'
  end
  
  devise_for :users, skip: [:registrations], controllers: {
    sessions: 'users/sessions'
  }

  devise_scope :user do
    get 'users/sign_up', to: 'subscriptions#new', as: :new_user_registration
  end
  
  # Rutas para el proceso de registro con pago
  resources :subscriptions, only: [:new, :create] do
    collection do
      get 'success'
      get 'cancel'
    end
  end

  # Ruta para los webhooks de Stripe
  post "stripe-webhooks", to: "stripe_webhooks#create"

  # Rutas existentes de tu aplicación
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Custom health check endpoints
  get "health" => "health#show", as: :health_check
  get "health/detailed" => "health#detailed", as: :detailed_health_check
  
  # Landing page route
  get 'landing', to: 'landing#index'
  
  # Set root to landing page
  root "landing#index"

  # Rutas para billing cuando el trial expira
  resource :billing, only: [:show, :create]
  
  # Rutas para upgrade después del trial
  resource :subscription_upgrade, only: [:new, :create] do
    collection do
      get 'success'
      get 'cancel'
    end
  end

  # Forms routes
  resources :forms do
    collection do
      get :new_from_ai
      post :generate_from_ai
    end

    member do
      patch :publish
      patch :unpublish
      post :duplicate
      get :analytics
      get :export
      get :preview
      post :test_ai_feature
      get :responses
      get :download_responses
      get :payment_setup_status
      get :has_payment_questions
      post :track_setup_abandonment
    end

    # Nested form questions routes
    resources :form_questions, path: 'questions' do
      member do
        post :move_up
        post :move_down
        post :duplicate
        post :ai_enhance
        get :preview
        get :analytics
        post :preview_conditional_logic
      end
      
      collection do
        patch :reorder  # Changed from post to patch to match controller
      end
    end

    # Google Sheets Integration routes
    namespace :integrations do
      resource :google_sheets, only: [:show, :create, :update, :destroy] do
        member do
          post :export
          post :toggle_auto_sync
        end
        
        collection do
          post :test_connection
        end
      end
    end
  end

  resources :form_responses, only: [] do
    resources :dynamic_questions, only: [] do
      member do
        post :answer
      end
    end
  end

  # Public form response routes (no authentication required)
  scope '/f' do
    get ':share_token', to: 'responses#show', as: :public_form
    post ':share_token/answer', to: 'responses#answer', as: :form_answer
    post ':share_token/save_draft', to: 'responses#save_draft', as: :save_draft_form
    post ':share_token/abandon', to: 'responses#abandon', as: :abandon_form
    get ':share_token/resume/:session_id', to: 'responses#resume', as: :resume_form
    get ':share_token/thank-you', to: 'responses#thank_you', as: :thank_you_form
    get ':share_token/preview', to: 'responses#preview', as: :public_form_preview
    
    # Payment routes
    get ':share_token/payments/config', to: 'payments#config', as: :payment_config
    post ':share_token/payments', to: 'payments#create', as: :create_payment
    post ':share_token/payments/:payment_intent_id/confirm', to: 'payments#confirm', as: :confirm_payment
  end

  # Dynamic question routes
  post '/f/:share_token/dynamic_questions/:id/answer', to: 'dynamic_questions#answer', as: :answer_dynamic_question
  
  # API routes
  namespace :api do
    namespace :v1 do
      # Discount code validation endpoint
      post 'discount_codes/validate', to: 'discount_codes#validate'
      
      resources :forms do
        member do
          patch :publish
          patch :unpublish
          post :duplicate
          get :analytics
          get :export
          get :preview
          post :test_ai_feature
          get :embed_code
        end
        
        collection do
          get :templates
        end

        # Nested responses routes
        resources :responses, except: [:new, :edit] do
          member do
            post :submit_answer
            post :complete
            post :abandon
            post :resume
            get :answers
          end

          collection do
            get :analytics
            get :export
          end
        end
      end

      # Standalone responses routes (for direct access)
      resources :responses, only: [:show, :update, :destroy] do
        member do
          post :submit_answer
          post :complete
          post :abandon
          post :resume
          get :answers
        end
      end

      # Payment setup routes (API version)
      get 'payment_setup/status', to: 'payment_setup#status'
      
      # Analytics routes (API version)
      namespace :analytics do
        post 'payment_setup', to: 'analytics#payment_setup'
        post 'payment_errors', to: 'analytics#payment_errors'
      end
    end
  end

  # Templates routes
  resources :templates, only: [:index, :show] do
    post 'instantiate', on: :member
  end

  # Profile routes
  resource :profile, only: [:show, :update]
  
  # Stripe settings (Premium users only)
  resource :stripe_settings, only: [:show, :update] do
    member do
      post :test_connection
      delete :disable
    end
  end

  # Subscription management
  resource :subscription_management, only: [:show, :create], controller: 'subscription_management' do
    member do
      delete :cancel
      post :reactivate
      post :update_payment_method
      get :success
      get :payment_method_success
    end
  end
  
  # Public blog routes (no subscription required)
  resources :blogs, only: [:index, :show]
  get 'blog', to: 'blogs#index'

  # Report routes for strategic analysis - CONSOLIDADO EN UN SOLO CONTROLADOR
  resources :reports, only: [:show] do
    member do
      get :download
      get :status
    end
    
    collection do
      post :generate
    end
  end

  # Payment setup routes (session-based for frontend)
  get 'payment_setup', to: 'payment_setup#index'
  post 'payment_setup/complete', to: 'payment_setup#complete', as: :complete_payment_setup
  get 'payment_setup/status', to: 'payment_setup#status'
  
  # Analytics routes (session-based for frontend)
  post 'analytics/payment_setup', to: 'analytics#payment_setup'
  post 'analytics/payment_errors', to: 'analytics#payment_errors'
  
  # Alias routes for cleaner URLs - TODOS APUNTAN A ReportsController
  get '/analysis_reports/:id', to: 'reports#show', as: 'analysis_report'
  get '/analysis_reports/:id/download', to: 'reports#download', as: 'download_analysis_report'
  get '/analysis_reports/:id/status', to: 'reports#status', as: 'status_analysis_report'

  # Google OAuth routes
  scope '/google_oauth', controller: 'google_oauth' do
    get 'connect', as: :google_oauth_connect
    get 'callback', as: :google_oauth_callback
    delete 'disconnect', as: :google_oauth_disconnect
    get 'status', as: :google_oauth_status
  end
  
  # Export routes for forms
  resources :forms, only: [] do
    resources :exports, only: [], controller: 'forms/exports' do
      collection do
        post :google_sheets
        get :status
      end
    end
  end

  # Admin routes (superadmin only)
  namespace :admin, constraints: ->(request) { 
    user = request.env['warden']&.user
    user&.superadmin?
  } do
    root 'dashboard#index', as: :dashboard
    
    resources :users do
      member do
        post :suspend
        post :reactivate
        post :send_password_reset
        delete :destroy
      end
    end
    
    resources :discount_codes do
      member do
        patch :toggle_status
      end
    end
    
    # Security monitoring routes
    resources :security, only: [:index] do
      collection do
        get :audit_logs
        get :security_report
        get :user_activity
        get :alerts
        post :block_ip
      end
    end
    
    # Payment analytics routes
    resources :payment_analytics, only: [:index] do
      collection do
        get :export
      end
    end
    
    # Admin notifications routes
    resources :notifications, only: [:index, :show, :destroy] do
      member do
        patch :mark_as_read
      end
      
      collection do
        patch :mark_all_as_read
        get :stats
      end
    end
    
    get 'dashboard', to: 'dashboard#index'
  end
end