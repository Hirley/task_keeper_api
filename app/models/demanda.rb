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
end
