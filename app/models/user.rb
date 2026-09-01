# frozen_string_literal: true

# Usuário da aplicação. Não há autocadastro: apenas um líder ou admin pode
# criar novos usuários (ver Api::V1::UsersController), por isso o módulo
# :registerable do Devise não é habilitado aqui.
#
# Três papéis: executor (cadastra/visualiza demandas), líder (mais
# gerencia demandas de qualquer usuário e cadastra/altera acessos) e admin
# (mais três privilégios exclusivos que nem o líder tem: telegram_chat_id
# — ver UsersController#user_params/#permission_params —, Webhooks de
# saída — ver app/models/ability.rb — e conceder/remover o próprio papel
# admin — ver #validar_atribuicao_de_papel).
#
# Fora esses três, admin não substitui o líder: os dois cadastram
# usuários e alternam qualquer outro entre executor e líder igualmente.
class User < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  enum :role, { executor: 0, lider: 1, admin: 2 }, default: :executor

  has_many :demandas, dependent: :restrict_with_error
  has_many :webhook_subscriptions, dependent: :destroy

  validates :name, presence: true
  validates :role, presence: true
  validate :validar_atribuicao_de_papel

  # Quem está cadastrando/editando este usuário. Não é coluna — os
  # controllers preenchem (ver UsersController#set_user/#create e
  # Api::V1::UsersController#create) pra #validar_atribuicao_de_papel
  # poder decidir.
  attr_accessor :ator

  # Declara que este registro está sendo escrito FORA de um contexto de
  # requisição: seeds, console, factory de teste. Sem isto, definir ou
  # mudar +role+ sem +ator+ é recusado (ver
  # #validar_atribuicao_de_papel).
  #
  # O nome é deliberadamente incômodo de escrever, e é assim de propósito:
  # quem o usa está afirmando "não há requisição aqui, não há fronteira a
  # defender". Isso precisa ser uma decisão consciente, não o atalho para
  # calar uma validação que apareceu no caminho.
  attr_accessor :ator_dispensado

  # Mensagem de erro de programação, não de usuário: nenhuma tela leva a
  # ela, porque os controllers sempre preenchem o ator. Se ela aparecer, o
  # caminho que a produziu é novo e precisa decidir de qual lado da
  # fronteira está — por isso ela nomeia as duas saídas.
  ERRO_SEM_ATOR = 'só pode ser definido informando quem está fazendo a alteração ' \
                  '(User#ator) — fora de uma requisição, use User#ator_dispensado'

  # Usado por TelegramNotifier para avisar o usuário sobre demandas
  # atrasadas (ver app/services/telegram_notifier.rb). É opcional — nem
  # todo usuário precisa configurar. Só o admin cadastra/edita esse valor
  # em /users (ver UsersController#telegram_chat_id_param); o próprio
  # usuário descobre o chat_id conversando com um bot como @userinfobot no
  # Telegram.
  validates :telegram_chat_id,
            format: { with: /\A-?\d+\z/, message: 'deve conter só números (o chat_id do Telegram)' },
            allow_blank: true

  # Sobrescreve o #reset_password do Devise (:recoverable) só pra também
  # marcar que o usuário já definiu a própria senha — usado tanto por
  # "esqueci minha senha" (e-mail, via Devise::PasswordsController#update,
  # e Telegram, via Users::SendPasswordResetViaTelegram) quanto, no fundo,
  # pelo mesmo mecanismo de token que dá base ao primeiro acesso (ver
  # #must_change_password e ApplicationController#exigir_troca_de_senha!).
  def reset_password(new_password, new_password_confirmation)
    self.must_change_password = false
    super
  end

  # Devise deixa #set_reset_password_token como protected (pensado só pro
  # uso interno de #send_reset_password_instructions, que já dispara o
  # e-mail junto). Esse wrapper público expõe só a geração do token, sem
  # enviar e-mail — usado por Users::SendPasswordResetViaTelegram pra
  # entregar o mesmo token por Telegram em vez de e-mail.
  def generate_reset_password_token
    set_reset_password_token
  end

  def lider?
    role == 'lider'
  end

  def executor?
    role == 'executor'
  end

  def admin?
    role == 'admin'
  end

  # Líder e admin compartilham a mesma visão "gerencial" nas telas
  # (dashboard, Demandas, formulário de Acessos) — usado nos lugares que
  # antes só checavam lider?, agora que existe um terceiro papel acima.
  def lider_ou_admin?
    lider? || admin?
  end

  def role_label
    case role
    when 'admin' then 'admin'
    when 'lider' then 'líder'
    else 'executor'
    end
  end

  def role_badge_class
    case role
    when 'admin' then 'tk-badge-admin'
    when 'lider' then 'tk-badge-lider'
    else 'tk-badge-executor'
    end
  end

  # Whitelist exigida pelo Ransack (usado em UsersController#index e, via
  # associação "user", em DemandasController#index para ordenar por
  # responsável). Sem isso o Ransack recusa buscar/ordenar por qualquer
  # atributo, por segurança. "id" está aqui só para o desempate estável na
  # ordenação da tela de Acessos (ver UsersController::SORTABLE_COLUMNS).
  def self.ransackable_attributes(_auth_object = nil)
    %w[name email role id]
  end

  def self.ransackable_associations(_auth_object = nil)
    []
  end

  private

  # O papel admin é a ÚNICA coisa que separa admin de líder: em
  # app/models/ability.rb o líder tem `can :manage, :all` com um único
  # `cannot :manage, WebhookSubscription`. Como o líder também gerencia
  # usuários (e isso é regra de negócio, não descuido), sem esta
  # validação ele contornava aquele `cannot` num request só — bastava um
  # PATCH no próprio usuário com role=admin, e no request seguinte já
  # administrava webhooks. Duas regras fecham isso:
  #
  #   * ninguém altera o próprio papel. Vale inclusive pro admin, o que
  #     de quebra impede o último admin de se rebaixar e deixar os
  #     webhooks sem ninguém que possa gerenciá-los;
  #   * só admin concede ou remove o papel admin — nas duas direções,
  #     senão um líder ainda poderia rebaixar todos os admins.
  #
  # O que o líder continua podendo fazer, porque é a regra documentada:
  # alternar qualquer outro usuário entre executor e líder.
  #
  # A ausência de ator é RECUSA, não dispensa. Antes era o contrário
  # (`return if ator.blank?`), e a diferença não é teórica: a invariante
  # valia só porque os dois controllers de hoje lembram de preencher o
  # ator. Qualquer caminho novo que esquecesse — um job, um importador,
  # uma rake task, um endpoint futuro — passava direto, em silêncio, e o
  # silêncio é o problema: um esquecimento virava brecha em vez de erro.
  #
  # Os lugares legítimos que escrevem papel sem ator (seeds, console,
  # factory) declaram isso com +ator_dispensado+. São poucos, e é neles
  # que o custo deve cair.
  def validar_atribuicao_de_papel
    return unless papel_mudou?
    return if ator_dispensado

    if ator.blank?
      errors.add(:role, ERRO_SEM_ATOR)
    elsif proprio_usuario?
      errors.add(:role, 'não pode ser alterado por você mesmo — peça a outro líder ou admin')
    elsif envolve_papel_admin? && !ator.admin?
      errors.add(:role, 'de admin só pode ser concedido ou removido por outro admin')
    end
  end

  # Em registro novo o papel está sempre sendo definido. Nos demais, só
  # interessa quando role de fato muda — sem esta guarda, um líder que
  # editasse apenas o NOME de um admin levaria um erro de permissão que
  # não tem nada a ver com o que ele fez.
  def papel_mudou?
    new_record? || will_save_change_to_role?
  end

  def proprio_usuario?
    persisted? && ator.id == id
  end

  # Tanto conceder (o papel novo é admin) quanto remover (o antigo era).
  def envolve_papel_admin?
    admin? || role_was == 'admin'
  end
end
