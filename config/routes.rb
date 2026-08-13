Rails.application.routes.draw do
  devise_for :users

  namespace :api do
    namespace :v1 do
      resources :demandas
      resources :users, only: %i[index show create destroy]
    end
  end

  resources :demandas
  resources :users, only: %i[index new create edit update destroy]

  get "acessibilidade", to: "pages#acessibilidade", as: :acessibilidade

  root "dashboard#index"
end
