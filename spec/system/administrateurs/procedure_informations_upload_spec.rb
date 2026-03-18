# frozen_string_literal: true

describe 'Administrateurs can upload files on procedure informations', js: true do
  let(:administrateur) { administrateurs(:default_admin) }
  let(:procedure) { create(:procedure, administrateur:) }

  before do
    login_as administrateur.user, scope: :user
  end

  describe 'logo' do
    scenario 'upload un logo de la démarche' do
      visit edit_admin_procedure_path(procedure)

      attach_file('Ajouter un logo de la démarche', Rails.root + 'spec/fixtures/files/logo_test_procedure.png')

      click_on 'Enregistrer'
      expect(page).to have_content('Démarche modifiée')

      expect(procedure.reload.logo).to be_attached

      # Test de suppression
      visit edit_admin_procedure_path(procedure)
      click_on 'Supprimer le fichier logo_test_procedure.png'

      wait_until { !procedure.reload.logo.attached? }
      expect(procedure.logo.attached?).to be(false)
    end
  end

  describe 'délibération' do
    scenario 'upload une délibération' do
      visit edit_admin_procedure_path(procedure)

      attach_file('Cadre juridique - texte à importer', Rails.root + 'spec/fixtures/files/piece_justificative_0.pdf')

      click_on 'Enregistrer'
      expect(page).to have_content('Démarche modifiée')

      expect(procedure.reload.deliberation).to be_attached

      # Test de suppression
      visit edit_admin_procedure_path(procedure)
      click_on 'Supprimer le fichier piece_justificative_0.pdf'

      wait_until { !procedure.reload.deliberation.attached? }
      expect(procedure.deliberation.attached?).to be(false)
    end
  end

  describe 'notice' do
    scenario 'upload une notice explicative' do
      visit edit_admin_procedure_path(procedure)

      attach_file('Notice explicative de la démarche', Rails.root + 'spec/fixtures/files/piece_justificative_0.pdf')

      click_on 'Enregistrer'
      expect(page).to have_content('Démarche modifiée')

      expect(procedure.reload.notice).to be_attached

      # Test de suppression
      visit edit_admin_procedure_path(procedure)
      click_on 'Supprimer le fichier piece_justificative_0.pdf'

      wait_until { !procedure.reload.notice.attached? }
      expect(procedure.notice.attached?).to be(false)
    end
  end
end
