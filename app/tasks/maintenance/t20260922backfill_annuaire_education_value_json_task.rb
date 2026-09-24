# frozen_string_literal: true

module Maintenance
  class T20260922backfillAnnuaireEducationValueJSONTask < MaintenanceTasks::Task
    # Documentation: value_json n'existait pas pour les champs annuaire_education
    # avant son ajout à Champs::AnnuaireEducationChamp#fetch_external_data : les
    # champs déjà remplis n'ont que `data`. Cette tâche recalcule et persiste
    # value_json pour ces lignes, à partir de la même logique que le fallback
    # de Champs::AnnuaireEducationChamp#value_json (qui pourra être retiré une
    # fois cette tâche passée en production). Run manuel en prod, pas de
    # run_on_first_deploy.
    #
    # Ces champs sont une aiguille dans la table champs : batcher la relation
    # fait parcourir des centaines de milliers de lignes avant qu'un batch se
    # remplisse, et le statement timeout coupe (cf.
    # T20260916stripWhitespaceFromSiretExternalIdTask). On parcourt donc la clé
    # primaire par intervalles fixes : la collection ne coûte que deux index
    # lookups, elle est identique à chaque reprise, et chaque requête est bornée
    # par l'intervalle plutôt que par un nombre de résultats.

    RANGE_SIZE = 1_000_000

    def collection
      first_id = ChampData.minimum(:id)
      return [] if first_id.nil?

      (first_id..ChampData.maximum(:id)).step(RANGE_SIZE).to_a
    end

    def process(from)
      Champs::AnnuaireEducationChamp
        .where(id: from...(from + RANGE_SIZE))
        .where(value_json: nil)
        .where.not(data: nil)
        .find_each { it.update_column(:value_json, it.value_json) }
    end
  end
end
