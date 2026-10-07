# frozen_string_literal: true

class DemandeurSiret < ApplicationRecord
  include ExternalDataConcern
  include APIEntrepriseExternalDataConcern

  belongs_to :dossier

  delegate :procedure, to: :dossier

  alias_attribute :external_id, :siret

  def self.submit!(dossier, siret)
    # A SIRET unverified is replaced by the one the demandeur just typed
    dossier.demandeur_siret&.destroy!
    # The demandeur typed the same SIRET : nothing to ask
    return :verified if dossier.etablissement&.siret == siret

    demandeur_siret = create!(dossier:, siret:)
    demandeur_siret.verify!
    # On success, verify! attached the etablissement to the dossier and destroyed this row
    return :verified if demandeur_siret.destroyed?

    # The API could not answer: the SIRET stays unverified and the cron will replay it
    if demandeur_siret.awaiting_fix?
      # The previous etablissement belongs to another SIRET, it no longer describes the demandeur.
      dossier.etablissement&.destroy!
      return :unverified
    end

    # Unknown or non diffusible SIRET: nothing is kept and the previous etablissement stays.
    demandeur_siret.destroy!
    demandeur_siret.fetch_external_data_exceptions.last&.code
  end

  def verify!
    fetch_now!
  rescue RetryableFetchError
    external_data_error! if may_external_data_error?
  end

  def external_data_sentry_tags = { dossier: dossier_id }

  private

  def ready_for_external_call? = Siret.new(siret:).valid?

  def fetch_external_data = fetch_sirene_etablissement(siret)

  def handle_result(result)
    case result
    in Success({ etablissement: })
      attach_and_forget(etablissement)
    else
      super
    end
  end

  def attach_and_forget(etablissement)
    transaction do
      Etablissement.where(dossier_id:).find_each(&:destroy!)
      etablissement.update!(dossier:)
      destroy!
    end

    APIEntrepriseService.perform_later_fetch_jobs(etablissement, procedure.id, dossier.user&.id)
    dossier.index_search_terms_later
  end

  def after_reset_external_data(opts = {})
    update(opts.merge(fetch_external_data_exceptions: []))
  end
end
