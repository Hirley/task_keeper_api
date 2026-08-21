# frozen_string_literal: true

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

  get 'relatorios', to: 'relatorios#show', as: :relatorios
  get 'relatorios/semanal.pdf', to: 'relatorios#semanal_pdf', as: :relatorio_semanal_pdf
  post 'relatorios/enviar_telegram', to: 'relatorios#enviar_telegram', as: :relatorio_enviar_telegram

  get 'acessibilidade', to: 'pages#acessibilidade', as: :acessibilidade

  root 'dashboard#index'
end
