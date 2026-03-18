# frozen_string_literal: true

describe 'Messagerie upload PJ', js: true do
  let(:procedure) { create(:procedure, :published, :for_individual) }

  def open_messagerie_form
    click_on 'Nouveau message'
    expect(page).to have_css('.message-textarea', visible: true, wait: 5)
  end

  describe 'usager' do
    let(:user) { create(:user, password: SECURE_PASSWORD) }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:, user:) }
    let!(:commentaire) { create(:commentaire, dossier:, email: 'instructeur@exemple.fr', body: 'Message de bienvenue') }

    before do
      login_as user, scope: :user
    end

    scenario 'envoie un message avec une pièce jointe' do
      visit dossier_path(dossier)
      click_on 'Messagerie'

      expect(page).to have_content('Message de bienvenue')
      open_messagerie_form

      fill_in 'commentaire_body', with: 'Bonjour, ci-joint mon justificatif'
      attach_file('Pièce jointe', Rails.root + 'spec/fixtures/files/piece_justificative_0.pdf')
      expect(page).to have_text('piece_justificative_0.pdf')

      # Test de suppression (la messagerie n'upload pas en direct, le fichier est géré en JS)
      click_on 'Supprimer le fichier'
      expect(page).not_to have_text('piece_justificative_0.pdf')

      # Re-upload
      attach_file('Pièce jointe', Rails.root + 'spec/fixtures/files/piece_justificative_0.pdf')
      expect(page).to have_text('piece_justificative_0.pdf')

      click_on 'Envoyer le message'

      expect(page).to have_text('Bonjour, ci-joint mon justificatif')
      expect(dossier.commentaires.last.piece_jointe).to be_attached
    end
  end

  describe 'instructeur' do
    let(:instructeur) { create(:instructeur, password: SECURE_PASSWORD) }
    let(:dossier) { create(:dossier, :en_construction, :with_individual, procedure:) }
    let!(:commentaire) { create(:commentaire, dossier:, email: dossier.user.email, body: 'Question de usager') }

    before do
      instructeur.assign_to_procedure(procedure)
      login_as instructeur.user, scope: :user
    end

    scenario 'envoie un message avec une pièce jointe' do
      visit instructeur_dossier_path(procedure, dossier)
      click_on 'Messagerie'

      expect(page).to have_content('Question de usager')
      open_messagerie_form

      fill_in 'commentaire_body', with: 'Merci de consulter le document ci-joint'
      attach_file('Pièce jointe', Rails.root + 'spec/fixtures/files/piece_justificative_0.pdf')
      expect(page).to have_text('piece_justificative_0.pdf')

      # Test de suppression (la messagerie n'upload pas en direct, le fichier est géré en JS)
      click_on 'Supprimer le fichier'
      expect(page).not_to have_text('piece_justificative_0.pdf')

      # Re-upload
      attach_file('Pièce jointe', Rails.root + 'spec/fixtures/files/piece_justificative_0.pdf')
      expect(page).to have_text('piece_justificative_0.pdf')

      click_on 'Envoyer le message'

      expect(page).to have_text('Merci de consulter le document ci-joint')
      expect(dossier.commentaires.last.piece_jointe).to be_attached
    end
  end
end
