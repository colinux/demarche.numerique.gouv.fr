# frozen_string_literal: true

describe 'Groupe instructeur signature upload', js: true do
  let(:administrateur) { administrateurs(:default_admin) }
  let(:procedure) { create(:procedure, administrateur:) }
  let(:groupe_instructeur) { procedure.defaut_groupe_instructeur }

  before do
    create(:attestation_template, procedure:, activated: true)
    login_as administrateur.user, scope: :user
  end

  scenario 'admin uploads a signature tampon for groupe instructeur' do
    visit admin_procedure_groupe_instructeur_path(procedure, groupe_instructeur)

    expect(page).to have_css('#tampon-attestation')
    expect(page).to have_button('Ajouter le tampon', disabled: true)

    find('input[type="file"]').attach_file(Rails.root + 'spec/fixtures/files/black.png')

    expect(page).to have_button('Ajouter le tampon', disabled: false)
    click_on 'Ajouter le tampon'

    expect(page).to have_content("Le tampon de l’attestation a bien été ajouté.")
    expect(groupe_instructeur.reload.signature).to be_attached

    # Test de suppression
    visit admin_procedure_groupe_instructeur_path(procedure, groupe_instructeur)
    click_on 'Supprimer le fichier black.png'

    wait_until { !groupe_instructeur.reload.signature.attached? }
    expect(groupe_instructeur.signature.attached?).to be(false)
  end
end
