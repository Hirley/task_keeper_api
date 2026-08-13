# Adiciona a "data" da demanda (data de referência escolhida pelo usuário
# no cadastro, ex.: data prevista/realizada) — diferente de created_at, que
# é o timestamp automático de quando o registro foi criado no sistema.
class AddDataToDemandas < ActiveRecord::Migration[8.1]
  def change
    add_column :demandas, :data, :date, null: false, default: -> { "CURRENT_DATE" }
  end
end
