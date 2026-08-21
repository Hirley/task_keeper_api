# frozen_string_literal: true

require_relative 'boot'

require 'rails/all'

Bundler.require(*Rails.groups)

module TaskKeeperApi
  class Application < Rails::Application
    config.load_defaults 8.1

    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = 'America/Fortaleza'
    config.i18n.default_locale = :'pt-BR'
    config.i18n.available_locales = %i[pt-BR en]
  end
end
