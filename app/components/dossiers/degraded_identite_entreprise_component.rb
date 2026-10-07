# frozen_string_literal: true

class Dossiers::DegradedIdentiteEntrepriseComponent < ApplicationComponent
  attr_reader :siret, :profile, :token_rejected, :not_found

  def initialize(siret:, profile:, token_rejected: false, not_found: false)
    @siret = siret
    @profile = profile
    @token_rejected = token_rejected
    @not_found = not_found
  end

  def call
    source = t('.source')
    header = safe_join([
      render(alert),
      render(Dossiers::AnnuaireEntrepriseLinkComponent.new(
        siret:,
        extra_class_names: 'pull-left'
      )),
    ])

    render Dossiers::ExternalChampComponent.new(source:, data:)
      .tap { it.with_header { header } }
  end

  def data
    [[Etablissement.human_attribute_name(:siret), helpers.pretty_siret(siret), data_to_copy: siret]]
  end

  # A refused token is the administration's business: to the usager we only
  # say the data is missing, without a delay we cannot promise.
  def alert_text
    return t('.not_found') if not_found
    return t('.insee_down') if !token_rejected
    return t('.unavailable') if profile == 'usager'

    t('.token_rejected')
  end

  def alert
    texts = [alert_text]
    texts << t('.dossier_blocked') if profile == 'instructeur' && !not_found

    Dsfr::AlertComponent.new(state: :warning, size: :sm, extra_class_names: 'fr-mb-2w pull-left width-100').tap do
      it.with_body { safe_join(texts, tag.br) }
    end
  end
end
