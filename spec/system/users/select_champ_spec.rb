# frozen_string_literal: true

describe 'Select champ', js: true do
  let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs: [{ type: :departements, libelle: 'Département', mandatory: false }]) }
  let(:dossier) { create(:dossier, :with_individual, procedure:, user: users.usager) }

  scenario 'an optional select set back to empty shows « Sélectionnez »' do
    login_as users.usager, scope: :user
    visit brouillon_dossier_path(dossier)

    select '01 – Ain', from: 'Département'
    expect(page).to have_css("option[value='01'][selected]")

    select 'Sélectionnez', from: 'Département'
    expect(page).to have_no_css("option[value='01'][selected]")
    expect(page).to have_select('Département', selected: 'Sélectionnez')
  end
end
