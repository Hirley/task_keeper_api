# Uma demanda pode ser criada por qualquer usuário (líder ou executor),
# mas apenas um líder pode editá-la ou excluí-la (ver app/models/ability.rb).
class Demanda < ApplicationRecord
  belongs_to :user

  enum :status, { pendente: 0, em_andamento: 1, concluida: 2 }, default: :pendente

  validates :title, presence: true
end
