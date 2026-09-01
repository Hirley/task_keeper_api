# frozen_string_literal: true

require 'capybara/rspec'
require 'selenium-webdriver'

# Driver dos system specs (ver spec/system). Headless de propósito: a
# suíte roda em container e em CI, onde não há display — e um navegador
# visível não acrescenta nada a uma verificação automatizada.
Capybara.register_driver :chrome_headless do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  options.add_argument('--headless=new')
  options.add_argument('--window-size=1400,1400')
  # Necessários dentro de container: sem --no-sandbox o Chrome não sobe
  # como root, e /dev/shm no Docker é pequeno demais para o navegador.
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')

  # A parte que faz o teste de CSP existir. Uma violação de CSP não
  # levanta erro nem quebra a renderização: o navegador só recusa o
  # recurso e escreve no console. Sem pedir o log do console, o spec
  # veria uma página aparentemente perfeita — que é exatamente como as
  # duas quebras anteriores passaram despercebidas.
  options.add_option('goog:loggingPrefs', { browser: 'ALL' })

  # CHROME_BIN existe para o container de verificação local, onde o
  # binário é o "chromium" do Debian e não o "google-chrome" que o
  # runner do GitHub traz pronto.
  chrome_bin = ENV.fetch('CHROME_BIN', nil)
  options.binary = chrome_bin if chrome_bin.present?

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Ajuda dos system specs a olharem o console do navegador.
module ConsoleDoNavegador
  # Violações de CSP e erros de JavaScript aparecem os dois como entrada
  # de console, e a distinção importa: a rede do runner pode falhar ao
  # buscar um CDN externo (o layout carrega Bootstrap, fontes do Google e
  # o widget do VLibras), e isso vira "Failed to load resource", não
  # violação de política. Filtrar pelo texto do próprio navegador mantém
  # o spec olhando só para o que ele se propõe a verificar.
  MARCA_DE_VIOLACAO = 'Content Security Policy'

  # O log do Chrome é drenado a cada leitura: chamar isto duas vezes
  # devolve só o que apareceu desde a última chamada.
  def violacoes_de_csp
    page.driver.browser.logs.get(:browser)
        .map(&:message)
        .select { |mensagem| mensagem.include?(MARCA_DE_VIOLACAO) }
  end
end
