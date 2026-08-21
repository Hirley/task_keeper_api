# frozen_string_literal: true

class CreateDemandas < ActiveRecord::Migration[8.1]
  def change
    create_table :demandas do |t|
      t.string :title, null: false
      t.text :description
      t.integer :status, null: false, default: 0
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :demandas, :status
  end
end
