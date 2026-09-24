# frozen_string_literal: true

class Dossiers::IdentiteEntrepriseBilanDetailPreview < ViewComponent::Preview
  include Dossiers::FakeEtablissementConcern

  def default
    render_with_template(
      template: 'dossiers/identite_entreprise_bilan_detail_preview',
      locals: { libelle: 'Résultat exercice', key: 'resultat_exercice', etablissement: }
    )
  end
end
