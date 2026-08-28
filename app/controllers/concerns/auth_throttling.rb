# frozen_string_literal: true

# Throttle das telas de autenticação — login e os dois fluxos de "esqueci
# minha senha" (e-mail do Devise e Telegram). Usa o rate_limit nativo do
# Rails 8 (ActionController::RateLimiting), sem rack-attack: uma
# dependência a menos, mesma filosofia do Paginatable (paginação sem
# kaminari).
#
# Por que throttle e não Devise :lockable: bloqueio de conta é ele mesmo
# um vetor de negação de serviço — quem souber o e-mail de alguém
# consegue trancar a conta da vítima de propósito, e aí ela precisa de um
# e-mail de desbloqueio pra voltar. O throttle só atrasa: passada a
# janela, a conta volta a funcionar sozinha, sem intervenção.
#
# Os limites são folgados de propósito, porque o rate_limit conta TODAS as
# requisições à ação, inclusive os logins que dão certo:
#
#   * por IP — um escritório inteiro atrás de um único IP de saída (NAT)
#     não pode ser bloqueado no meio do expediente. 20 em 3 minutos passa
#     longe do uso normal de uma equipe e ainda assim mata força bruta,
#     que precisa de milhares de tentativas por minuto pra ter graça.
#   * por e-mail — fecha o ataque distribuído, em que cada tentativa vem
#     de um IP diferente e o limite por IP nunca chega perto de estourar.
#     10 em 20 minutos: ninguém erra a própria senha 10 vezes seguidas
#     sem partir pro "esqueci minha senha".
#
# Ver também config/initializers/devise.rb (password_length): o throttle
# é metade da proteção, o tamanho mínimo da senha é a outra.
module AuthThrottling
  extend ActiveSupport::Concern

  LIMITE_POR_IP = 20
  JANELA_POR_IP = 3.minutes

  LIMITE_POR_EMAIL = 10
  JANELA_POR_EMAIL = 20.minutes

  MENSAGEM_LIMITE = 'Muitas tentativas seguidas. Aguarde alguns minutos e tente novamente.'

  class_methods do
    # +voltar_para+: lambda com o path pra onde redirecionar quando o
    # limite estoura (avaliado no contexto do controller, então pode usar
    # os helpers de rota normalmente).
    #
    # Redireciona em vez de responder 429 porque quem esbarra nisso é uma
    # pessoa num formulário: precisa ver a mensagem na tela. Um 429 seco
    # apareceria como erro genérico do Turbo, sem explicar nada.
    def throttle_auth_attempts(only:, voltar_para:)
      recusar = -> { redirect_to instance_exec(&voltar_para), alert: MENSAGEM_LIMITE }

      # Os dois limites convivem no mesmo controller porque a chave de
      # cache do rate_limit inclui o retorno do +by+ — os prefixos "ip:" e
      # "email:" garantem que um contador não sobrescreva o outro.
      rate_limit to: LIMITE_POR_IP, within: JANELA_POR_IP, only: only,
                 by: -> { "ip:#{request.remote_ip}" }, with: recusar

      rate_limit to: LIMITE_POR_EMAIL, within: JANELA_POR_EMAIL, only: only,
                 by: -> { "email:#{email_da_tentativa}" }, with: recusar
    end
  end

  private

  # O e-mail chega como user[email] nas telas do Devise e como email na
  # tela do Telegram. Normaliza igual ao Devise (case_insensitive_keys /
  # strip_whitespace_keys) pra que "  ALVO@X.COM " e "alvo@x.com" caiam
  # no mesmo contador, senão o limite por e-mail é contornável só mudando
  # a caixa das letras.
  #
  # Sem e-mail no corpo (requisição malformada), cai no IP: evita que
  # todas essas tentativas dividam um único contador de chave vazia.
  def email_da_tentativa
    # is_a?(Parameters) e não dig(:user, :email): num corpo malformado
    # como "user=texto", params[:user] vem String e o dig levantaria
    # TypeError — 500 numa rota que qualquer um alcança sem login.
    escopo = params[:user]
    bruto = escopo.is_a?(ActionController::Parameters) ? escopo[:email] : params[:email]

    bruto.to_s.strip.downcase.presence || request.remote_ip
  end
end
