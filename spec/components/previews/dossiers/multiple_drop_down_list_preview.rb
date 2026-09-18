# frozen_string_literal: true

class Dossiers::MultipleDropDownListPreview < ViewComponent::Preview
  def default
    champ = Champs::MultipleDropDownListChamp.new(
      type_de_champ: TypeDeChamp.new(type_champ: :multiple_drop_down_list, libelle: "Choix multiples", drop_down_options: ["Option 1", "Option 2", "Option 3"]),
      dossier: Dossier.new(id: 1, procedure: Procedure.new(id: 1)),
      value: '["Option 1", "Option 3"]'
    )

    render_with_template(
      template: 'dossiers/multiple_drop_down_list_preview',
      locals: { champ: }
    )
  end
end
