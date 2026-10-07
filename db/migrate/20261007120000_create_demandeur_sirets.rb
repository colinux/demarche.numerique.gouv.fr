# frozen_string_literal: true

class CreateDemandeurSirets < ActiveRecord::Migration[8.1]
  def change
    create_table :demandeur_sirets do |t|
      t.references :dossier, null: false, foreign_key: true, index: { unique: true }
      t.string :siret, null: false
      t.string :external_state
      t.string :fetch_external_data_exceptions, array: true
      t.timestamps

      t.index :id, where: "external_state = 'degraded'", name: 'index_demandeur_sirets_on_degraded_external_state'
    end
  end
end
