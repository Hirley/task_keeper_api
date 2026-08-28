# frozen_string_literal: true

# Content Security Policy. O objetivo principal aqui é um só: se algum dia
# entrar HTML de terceiro numa página (um XSS armazenado num título de
# demanda, por exemplo), o navegador se recuse a EXECUTAR script que não
# venha de uma origem declarada abaixo.
#
# Por isso script-src não tem 'unsafe-inline'. Isso custou uma refatoração:
# os botões da barra de acessibilidade e o link do tour usavam onclick
# inline, e passaram a declarar data-tk-action, resolvido por um único
# listener delegado em app/javascript/application.js. Com 'unsafe-inline'
# ligado, um XSS injetaria <script> à vontade e o CSP inteiro viraria
# enfeite — não vale a pena manter a diretiva só para poupar cinco atributos.
#
# O único script inline que sobra é a inicialização do widget VLibras, que
# vai por nonce (ver o layout). O importmap também recebe nonce, sozinho —
# o importmap-rails já injeta request.content_security_policy_nonce nas
# tags que gera.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.base_uri    :self

    # Não há <object>/<embed> em lugar nenhum do app, e a aplicação nunca
    # deve ser embutida em iframe de terceiro (clickjacking).
    policy.object_src      :none
    policy.frame_ancestors :none

    # jsdelivr: Bootstrap (CSS e JS), com SRI no layout.
    # vlibras.gov.br: widget de tradução para Libras.
    policy.script_src :self, 'https://cdn.jsdelivr.net', 'https://vlibras.gov.br'

    # 'unsafe-inline' aqui é uma concessão consciente, e não descuido:
    #
    #   * o próprio Bootstrap escreve style inline em tempo de execução
    #     (posicionamento de tooltip, dropdown, collapse);
    #   * as barras de carga do dashboard e do relatório calculam a largura
    #     no servidor (`style: "width: #{...}%"`), o que é um atributo de
    #     estilo, não uma tag <style> — e nonce não vale para atributo.
    #
    # A conta de risco é diferente da do script: injeção de CSS permite
    # deformar a página, não executar código. Trocar isso por uma
    # refatoração de todo o CSS dinâmico seria pagar caro por pouco.
    policy.style_src :self, :unsafe_inline, 'https://cdn.jsdelivr.net', 'https://fonts.googleapis.com'

    policy.font_src    :self, :data, 'https://fonts.gstatic.com'
    policy.img_src     :self, :data, 'https://cdn.jsdelivr.net', 'https://vlibras.gov.br'
    policy.media_src   :self, 'https://vlibras.gov.br'
    policy.connect_src :self, 'https://vlibras.gov.br'

    # form_action fechado em :self — um XSS que injetasse um <form>
    # apontando para fora não conseguiria exfiltrar o que o usuário digitar.
    policy.form_action :self
  end

  # Nonce preso à sessão, e não aleatório por requisição. A escolha não é
  # óbvia e custou duas idas ao navegador.
  #
  # Com nonce novo a cada resposta, a primeira navegação do Turbo Drive já
  # quebrava o widget do VLibras: o Turbo troca o <body> sem criar um
  # documento novo, então continua valendo o CSP da PRIMEIRA resposta. O
  # script inline que vem no HTML seguinte carrega o nonce daquela outra
  # requisição, que a política em vigor não conhece, e é bloqueado. O mesmo
  # valeria para a tag <script type="importmap">, que ainda por cima tem
  # data-turbo-track="reload" — nonce mudando a cada resposta faria o Turbo
  # concluir que o <head> mudou e recarregar a página inteira a cada clique.
  #
  # O gerador padrão do scaffold do Rails (`request.session.id.to_s`) também
  # não serve sozinho: enquanto a sessão não existe, session.id é nil e o
  # header sai com `'nonce-'` vazio, que bloqueia todo script inline. Ler e
  # escrever uma chave na sessão resolve os dois casos de uma vez, porque a
  # leitura já força a sessão a existir.
  #
  # O preço é que o nonce vale enquanto a sessão durar, em vez de uma
  # resposta só. Quem conseguisse ler uma resposta do usuário poderia
  # reaproveitá-lo — mas quem lê a resposta já leva o cookie de sessão
  # junto, que é bem pior.
  config.content_security_policy_nonce_generator = lambda do |request|
    request.session[:csp_nonce] ||= SecureRandom.base64(16)
  end

  # Só script-src. Se o nonce fosse aplicado também a style-src, o
  # 'unsafe-inline' acima passaria a ser ignorado pelos navegadores que
  # entendem CSP nível 3 — e aí o estilo dinâmico quebraria.
  config.content_security_policy_nonce_directives = %w[script-src]
end
