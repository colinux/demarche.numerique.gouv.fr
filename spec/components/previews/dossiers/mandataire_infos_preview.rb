# frozen_string_literal: true

class Dossiers::MandataireInfosPreview < ViewComponent::Preview
  def default
    render_with_template(
      template: 'dossiers/mandataire_infos_preview',
      locals: {
        user_deleted: false,
        email: 'usager@exemple.fr',
        dossier: Dossier.new(
          mandataire_first_name: 'Jean',
          mandataire_last_name: 'Dupont',
          for_tiers: true
        ),
      }
    )
  end
end
