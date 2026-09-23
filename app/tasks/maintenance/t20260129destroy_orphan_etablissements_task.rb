# frozen_string_literal: true

module Maintenance
  # Supprime les établissements orphelins créés par le bug dans SiretChamp#after_reset_external_data
  # Ces établissements n'ont ni dossier_id ni champ associé et ne sont plus accessibles.
  #
  # La table compte des millions de lignes : chercher les orphelins sur toute la table
  # dépasse le statement timeout. On parcourt la clé primaire par plages fixes, chaque
  # plage ne coûtant qu'une anti-jointure bornée sur l'index champs.etablissement_id.
  class T20260129destroyOrphanEtablissementsTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    RANGE_SIZE = 10_000

    def collection
      first_id = Etablissement.minimum(:id)
      return [] if first_id.nil?

      (first_id..Etablissement.maximum(:id)).step(RANGE_SIZE).to_a
    end

    def process(from)
      Etablissement
        .where(id: from...(from + RANGE_SIZE), dossier_id: nil)
        .where.missing(:champ_data)
        .find_each(&:destroy!)
    end
  end
end
