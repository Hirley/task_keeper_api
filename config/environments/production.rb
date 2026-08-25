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

  config.action_mailer.perform_caching = false
  # Ver comentário equivalente em config/environments/test.rb. Mesmo
  # fallback de mailer_sender (config/initializers/devise.rb) pra sempre
  # gerar um link válido mesmo sem APP_HOST configurado (ex.: link do
  # e-mail/Telegram de redefinição de senha aponta pra esse host).
  config.action_mailer.default_url_options = { host: ENV.fetch('APP_HOST', 'task-keeper.local') }

  config.i18n.fallbacks = true

  config.active_record.dump_schema_after_migration = false

  config.active_record.attributes_for_inspect = [:id]

  config.hosts << ENV['APP_HOST'] if ENV['APP_HOST']
end
