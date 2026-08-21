# frozen_string_literal: true

# Adiciona a "data" da demanda (data de referência escolhida pelo usuário
# no cadastro, ex.: data prevista/realizada) — diferente de created_at, que
# é o timestamp automático de quando o registro foi criado no sistema.
#
# O SQLite não aceita um default "não constante" (como CURRENT_DATE) num
# ADD COLUMN — só sabe preencher as linhas já existentes com um valor
# literal fixo (SQLite3::SQLException: Cannot add a column with
# non-constant default). Por isso adicionamos a coluna sem default,
# preenchemos as linhas existentes via UPDATE e só depois travamos o
# NOT NULL. Novos registros continuam vindo com a data de hoje por conta
# do `attribute :data, :date, default: -> { Date.current }` no model.
class AddDataToDemandas < ActiveRecord::Migration[8.1]
  def up
    add_column :demandas, :data, :date
    execute "UPDATE demandas SET data = DATE('now') WHERE data IS NULL"
    change_column_null :demandas, :data, false
  end

  def down
    remove_column :demandas, :data
  end
end
