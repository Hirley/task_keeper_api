# frozen_string_literal: true

Rails.application.routes.draw do
  # Controllers próprios só pra pendurar o throttle de tentativas nas duas
  # ações que aceitam e-mail/senha sem login (ver AuthThrottling); o resto
  # do comportamento e todos os helpers de rota continuam os do Devise.
  devise_for :users, controllers: {
    sessions: 'users/sessions',
    passwords: 'users/passwords'
  }

  # Primeiro acesso: troca obrigatória da senha provisória cadastrada
  # pelo líder/admin (ver ApplicationController#exigir_troca_de_senha! e
  # DefinirSenhaController).
  get 'definir-senha', to: 'definir_senha#edit', as: :edit_definir_senha
  patch 'definir-senha', to: 'definir_senha#update', as: :definir_senha

  # Alternativa ao "esqueci minha senha" por e-mail (devise_for acima já
  # cobre /users/password) pra quem tem Chat ID do Telegram cadastrado
  # (ver TelegramPasswordResetsController).
  get 'senha/telegram', to: 'telegram_password_resets#new', as: :new_telegram_password_reset
  post 'senha/telegram', to: 'telegram_password_resets#create', as: :telegram_password_resets

  # Guia interativo (tour) do dashboard — ver app/javascript/application.js
  # (TkGuideTour) e TourController. Só marca que o usuário já viu, pra não
  # disparar sozinho de novo (o botão 🧭 na navbar sempre deixa rever).
  patch 'tour/concluir', to: 'tour#concluir', as: :concluir_tour

  namespace :api do
    namespace :v1 do
      resources :demandas
      resources :users, only: %i[index show create destroy]
    end
  end

  resources :demandas
  resources :users, only: %i[index new create edit update destroy]
  resources :webhook_subscriptions, path: 'webhooks', only: %i[index new create edit update destroy]

  get 'relatorios', to: 'relatorios#show', as: :relatorios
  get 'relatorios/semanal.pdf', to: 'relatorios#semanal_pdf', as: :relatorio_semanal_pdf
  post 'relatorios/enviar_telegram', to: 'relatorios#enviar_telegram', as: :relatorio_enviar_telegram

  get 'acessibilidade', to: 'pages#acessibilidade', as: :acessibilidade
  get 'busca', to: 'search#index', as: :busca

  root 'dashboard#index'
end
