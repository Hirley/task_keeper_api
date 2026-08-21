# frozen_string_literal: true

# Uma demanda pode ser criada por qualquer usuário (líder ou executor),
# mas apenas um líder pode editá-la ou excluí-la (ver app/models/ability.rb) —
# isso vale também para o campo "data": como só o líder tem permissão para
# atualizar uma demanda já existente, só ele consegue alterar a data depois
# que ela foi cadastrada.
class Demanda < ApplicationRecord
  belongs_to :user

  enum :status, { pendente: 0, em_andamento: 1, concluida: 2 }, default: :pendente

  # Data de referência da demanda (não confundir com created_at, que é o
  # timestamp automático de quando o registro foi criado). Por padrão vem
  # preenchida com a data atual no momento em que o registro é instanciado,
  # mas pode ser alterada no formulário de cadastro.
  attribute :data, :date, default: -> { Date.current }

  validates :title, presence: true
  validates :data, presence: true

  # Evita notificação duplicada: lib/tasks/telegram_notifications.rake só
  # avisa o responsável quando atraso_notificado_em está vazio. Se a
  # demanda deixar de estar atrasada (data adiada para hoje/futuro, ou
  # marcada como concluída), zera essa marca — assim, se ela atrasar de
  # novo no futuro, o responsável é avisado de novo.
  before_save :zerar_notificacao_de_atraso_se_nao_esta_mais_atrasada, if: -> { data_changed? || status_changed? }

  # Whitelist exigida pelo Ransack (usado em DemandasController#index para
  # filtro/ordenação — ver SORTABLE_COLUMNS lá). Sem isso o Ransack recusa
  # buscar/ordenar por qualquer atributo, por segurança. "id" está aqui só
  # para permitir o desempate estável na ordenação (mesmo critério que já
  # existia antes do Ransack).
  def self.ransackable_attributes(_auth_object = nil)
    %w[title data status created_at id]
  end

  # "user" habilita ordenar por atributos da associação (ex.: "user_name",
  # usado para ordenar por responsável — ver Demanda.ransackable_attributes
  # equivalente em User).
  def self.ransackable_associations(_auth_object = nil)
    %w[user]
  end

  private

  def zerar_notificacao_de_atraso_se_nao_esta_mais_atrasada
    return if atraso_notificado_em.blank?

    self.atraso_notificado_em = nil if data >= Date.current || concluida?
  end
end
