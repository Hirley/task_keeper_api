# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  # Eager loading em CI (ENV["CI"].present?) foi tentado para pegar erros
  # de autoload cedo, mas expôs um FrozenError ("can't modify frozen
  # Array") ao carregar as autoload paths de devise/actionmailbox/
  # activestorage juntas (ver run que falhou por isso na Action CI #3).
  # Não conseguimos investigar a fundo neste ambiente (sem bundle install
  # local funcionando) — desligado por enquanto para o CI rodar; ver
  # TODO no README (seção "Integração contínua").
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  config.action_dispatch.show_exceptions = :none

  config.action_controller.allow_forgery_protection = false

  config.active_storage.service = :test

  config.action_mailer.perform_caching = false
  config.action_mailer.delivery_method = :test

  config.active_support.deprecation = :stderr

  config.action_controller.raise_on_missing_callback_actions = true
end
