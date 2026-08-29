Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  devise_for :users, controllers: { sessions: "users/sessions", passwords: "users/passwords" }

  namespace :api do
    namespace :v1 do
      resource :signup, only: [ :create ], controller: "/users/signups"
      resource :me, only: [ :show ], controller: "me"
      resources :facilities, only: [ :index, :create, :update ]
      resources :users, only: [ :index, :create, :update ]
      resources :patients, only: [ :index, :create, :update ]
      resources :appointments, only: [ :index, :create, :update ] do
        member do
          post :advance_status
          post :revert_status
          post :cancel
          post :uncancel
        end
      end
      resources :admissions, only: [ :index, :create, :update ] do
        member do
          post :advance_status
          post :revert_status
          post :cancel
          post :uncancel
        end
      end
    end
  end
end
