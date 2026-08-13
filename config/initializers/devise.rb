# Configuração mínima do Devise para a API + interface web do task_keeper_api.
Devise.setup do |config|
  config.mailer_sender = "no-reply@task-keeper.local"

  require "devise/orm/active_record"

  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]
  config.skip_session_storage = [:http_auth]
  config.stretches = Rails.env.test? ? 1 : 12
  config.reconfirmable = true
  config.expire_all_remember_me_on_sign_out = true
  config.password_length = 6..128
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/
  config.reset_password_within = 6.hours
  config.sign_out_via = :delete

  # Não há autocadastro: apenas o líder pode criar novos usuários,
  # por isso o módulo :registerable não é habilitado no model User.
end
