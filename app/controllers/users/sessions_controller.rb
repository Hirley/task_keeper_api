# frozen_string_literal: true

module Users
  # Só existe pra pendurar o throttle no login (ver AuthThrottling); todo
  # o resto do comportamento continua sendo o do Devise. Registrado em
  # config/routes.rb via `devise_for :users, controllers: {...}` — os
  # helpers de rota (new_user_session_path etc.) não mudam.
  class SessionsController < Devise::SessionsController
    include AuthThrottling

    throttle_auth_attempts only: :create, voltar_para: -> { new_user_session_path }
  end
end
