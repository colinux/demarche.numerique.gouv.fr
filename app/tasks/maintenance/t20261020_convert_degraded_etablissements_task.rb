# frozen_string_literal: true

module Maintenance
  class T20261020ConvertDegradedEtablissementsTask < MaintenanceTasks::Task
    def collection
      Etablissement
        .where(adresse: nil)
        .where.not(siret: nil)
        .joins(:dossier)
        .where.missing(:champ_data)
    end

    def process(etablissement)
      return if !etablissement.persisted?

      Dossier.no_touching do
        Etablissement.transaction do
          DemandeurSiret.create_or_find_by!(dossier_id: etablissement.dossier_id) do |demandeur_siret|
            demandeur_siret.siret = etablissement.siret
            demandeur_siret.external_state = 'degraded'
          end
          etablissement.destroy!
        end
      end
    end
  end
end
