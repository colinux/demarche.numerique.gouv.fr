# frozen_string_literal: true

describe 'EPCI champ', js: true do
  let(:procedure) { create(:procedure, :published, :for_individual, public_type_de_champs: [{ type: :epci, libelle: 'Intercommunalité', mandatory: true }]) }
  let(:dossier) { create(:dossier, :with_individual, procedure:, user: users.usager) }

  scenario 'the EPCI list starts on its placeholder, and the error link follows the list to fill' do
    login_as users.usager, scope: :user
    visit brouillon_dossier_path(dossier)

    click_on 'Déposer le dossier'
    expect(page).to have_link('Intercommunalité', href: "##{find_field('Le département de l’EPCI')[:id]}")

    select '01 – Ain', from: 'Le département de l’EPCI'
    expect(page).to have_select('EPCI', exact: true, selected: 'Sélectionnez')

    click_on 'Déposer le dossier'
    expect(page).to have_link('Intercommunalité', href: "##{find_field('EPCI', exact: true)[:id]}")
  end
end
