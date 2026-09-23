# frozen_string_literal: true

module Maintenance
  class T20260914degradeSiretChampsWithStubEtablissementTask < MaintenanceTasks::Task
    # An API Entreprise outage used to leave the champ with a stub etablissement,
    # in external_error, or in fetched for the legacy champs that
    # T20251029backfillChampSiretExternalStateTask moved along with the others.
    # Nothing repairs those any more, and their dossier reads as degraded
    # forever: it can never be accepted. Send them where the cron can complete
    # them.

    include RunnableOnDeployConcern

    run_on_first_deploy

    # Taken from the etablissements: the stubs are rare, and the same scan over
    # champs, a far larger table, times out.
    def collection
      Etablissement
        .where(adresse: nil)
        .joins(:champ_data)
        .merge(Champs::SiretChamp.where(external_state: ['fetched', 'external_error']))
    end

    def process(etablissement)
      champ = etablissement.champ_data

      # Some champs never got their external_id backfilled; the stub and the
      # legacy value column carry the siret the user typed, and dropping it
      # would lose it for good.
      siret = champ.siret.presence || champ.value.presence || etablissement.siret

      # Destroying the stub touches the champ (Etablissement has_one champ_data,
      # touch: true), and the champ touches its dossier in turn. A backfill must
      # neither show the instructeur a "modified" champ nor move the dossier up
      # their list: Dossier.no_touching alone would only stop the second one.
      ChampData.no_touching do
        champ.update_columns(columns_for(champ, siret))
        etablissement.destroy
      end
    end

    def count
      # the champs table is large, a COUNT triggers a PG statement timeout
    end

    private

    # No siret to retry with: the champ holds nothing, and only the stub makes
    # its dossier read as degraded. Sending it to degraded would feed the cron
    # a blank identifier, so it goes back to idle, the state of an empty champ.
    def columns_for(champ, siret)
      return { etablissement_id: nil, external_state: nil } if siret.blank?

      {
        etablissement_id: nil,
        external_id: siret,
        value: siret,
        external_state: 'degraded',
        # A champ from before the column reads its "Modifié le" date off
        # updated_at, which every replay of the cron will bump. Freeze the
        # date it shows today, like the backfill of the column did.
        value_updated_at: champ[:value_updated_at] || champ.updated_at,
      }
    end
  end
end
