# frozen_string_literal: true

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'cancan/matchers'
# Explícito, e não um Dir[] varrendo spec/support: só há dois arquivos
# ali, e um require nomeado diz de onde vem o driver dos system specs
# (ver o comentário em spec/support/factory_bot.rb sobre o glob que este
# projeto optou por não usar).
require_relative 'support/system'

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request

  # Nos system specs o navegador é um cliente HTTP de verdade, então os
  # helpers de request do Devise não valem — quem autentica é o Warden em
  # modo de teste, que injeta a sessão no servidor que a Capybara sobe no
  # mesmo processo. É o que evita ter que preencher o formulário de login
  # em todo spec só para chegar na tela que interessa.
  config.include Warden::Test::Helpers, type: :system
  config.include ConsoleDoNavegador, type: :system

  config.before(type: :system) do
    driven_by :chrome_headless
    Warden.test_mode!
  end

  config.after(type: :system) { Warden.test_reset! }

  # O throttle das telas de autenticação (ver AuthThrottling) guarda o
  # contador de tentativas no cache, que em teste é :memory_store e
  # sobrevive entre exemplos. Sem limpar, um spec que faz vários POST em
  # /users/sign_in deixaria o contador alto e derrubaria specs seguintes
  # sem relação nenhuma com throttle.
  #
  # Os dois stores são o mesmo objeto na configuração padrão do Rails
  # (ActionController::Base.cache_store recebe o Rails.cache no boot) —
  # limpar os dois é barato e não depende desse detalhe continuar valendo.
  config.before do
    Rails.cache.clear
    ActionController::Base.cache_store.clear
  end

  # Ver config/initializers/devise.rb e spec/devise_warden_boot_spec.rb.
  # A invariante é "o Warden já conhece as estratégias antes da primeira
  # requisição", e depois de qualquer requisição ela passa a valer de
  # qualquer jeito — então medir dentro de um exemplo só funcionaria se
  # esse exemplo fosse o primeiro da suíte, que é exatamente o tipo de
  # dependência de ordem que deixou o bug escondido. O retrato é tirado
  # aqui, antes de qualquer exemplo rodar.
  config.add_setting :estrategias_do_warden_no_boot
  config.before(:suite) do
    RSpec.configuration.estrategias_do_warden_no_boot =
      Devise.warden_config[:default_strategies].dup
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
