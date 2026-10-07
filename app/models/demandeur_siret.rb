# frozen_string_literal: true

class DemandeurSiret < ApplicationRecord
  include ExternalDataConcern
  include APIEntrepriseExternalDataConcern

  belongs_to :dossier

  delegate :procedure, to: :dossier

  alias_attribute :external_id, :siret

  def verify!
    fetch_now!
  rescue RetryableFetchError
    external_data_error! if may_external_data_error?
  end

  def external_data_sentry_tags = { dossier: dossier_id }

  private

  def ready_for_external_call? = Siret.new(siret:).valid?

  def fetch_external_data
    return token_unusable_failure if !procedure.api_entreprise_token_usable?

    case APIEntreprise::Sirene.fetch_etablissement(siret, procedure.id)
    in Success(etablissement)
      procedure.forget_api_entreprise_token_rejection!
      Success(etablissement:)
    in Failure => failure
      api_entreprise_failure(failure)
    end
  end

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
