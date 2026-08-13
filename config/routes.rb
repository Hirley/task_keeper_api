Rails.application.routes.draw do
  devise_for :users

  namespace :api do
    namespace :v1 do
      resources :demandas
      resources :users, only: %i[index show create]
    end
  end

  resources :demandas, only: %i[index]

  root "demandas#index"
end
