# frozen_string_literal: true

Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true

  config.active_storage.service = :local

  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')

  # Ligado por padrão; só desliga com FORCE_SSL=false, que existe pro
  # `docker compose up` local — ele serve em http://localhost, sem TLS, e
  # o redirect deixaria a demo inacessível (ver docker-compose.yml).
  #
  # assume_ssl anda junto: quando um proxy/load balancer termina o TLS e
  # repassa a request como HTTP interno, sem ele o force_ssl entraria em
  # laço de redirect.
  force_ssl = ENV.fetch('FORCE_SSL', 'true') != 'false'

  # Além de redirecionar http→https, isto é o que marca o cookie de
  # sessão como Secure e envia HSTS.
  config.assume_ssl = force_ssl
  config.force_ssl = force_ssl

  config.action_mailer.perform_caching = false
  # Ver comentário equivalente em config/environments/test.rb. Mesmo
  # fallback de mailer_sender (config/initializers/devise.rb) pra sempre
  # gerar um link válido mesmo sem APP_HOST configurado (ex.: link do
  # e-mail/Telegram de redefinição de senha aponta pra esse host).
  #
  # O protocol é tão importante quanto o host aqui: sem ele o link de
  # redefinição de senha sai como http:// mesmo atrás de um proxy que só
  # fala https — nenhum load balancer conserta uma URL que o ActionMailer
  # já escreveu dentro do corpo do e-mail, e esse link carrega o token de
  # reset em texto claro.
  config.action_mailer.default_url_options = {
    host: ENV.fetch('APP_HOST', 'task-keeper.local'),
    protocol: force_ssl ? 'https' : 'http'
  }

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false

  config.active_record.attributes_for_inspect = [:id]

  config.hosts << ENV['APP_HOST'] if ENV['APP_HOST']
end
