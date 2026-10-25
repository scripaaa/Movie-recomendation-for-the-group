Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: [ :new, :create ]
  resource :profile, only: :show
  resources :movies, only: [ :index, :show ], param: :tmdb_id, constraints: { tmdb_id: /\d+/ }
  put "movies/:tmdb_id/rating", to: "ratings#update", as: :movie_rating, constraints: { tmdb_id: /\d+/ }
  resources :rooms, only: [ :index, :new, :create, :show ] do
    get :selection, on: :member
    post :selection, on: :member, action: :create_selection
    resources :quizzes, only: [ :create, :show ], controller: "room_quizzes" do
      post :vote, on: :member
      post :finish, on: :member
    end
  end
  get "invitations/:token", to: "room_invitations#show", as: :room_invitation
  post "invitations/:token", to: "room_invitations#create"
  get "room", to: "rooms#current", as: :current_room
  get "room/selection", to: "rooms#current_selection", as: :current_room_selection
  resources :ratings, only: :index
  resource :recommendations, only: :show
  root "profiles#show"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
