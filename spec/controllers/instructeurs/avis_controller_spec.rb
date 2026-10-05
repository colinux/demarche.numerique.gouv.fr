# frozen_string_literal: true

describe Instructeurs::AvisController, type: :controller do
  context 'with a instructeur signed in' do
    render_views

    let(:instructeur) { instructeurs.default }
    let(:procedure) { procedures.individual }
    let(:dossier) { dossiers.en_instruction }
    let(:pending_avis) { avis.pending }

    before { sign_in(instructeur.user) }

    describe "#revoker" do
      let!(:notification) { create(:dossier_notification, dossier:, instructeur:, notification_type: :attente_avis) }

      before do
        # notifications are only destroyed once the dossier has no unanswered avis left
        avis.confidentiel.destroy
        patch :revoquer, params: { procedure_id: procedure.id, id: pending_avis.id, statut: 'a-suivre' }
      end

      it "revoke the dossier" do
        expect(flash.notice).to eq("#{pending_avis.expert.email} ne peut plus donner son avis sur ce dossier.")
      end

      context "when attente_avis notifications exists" do
        it "destroys all attente_avis notifications" do
          expect(DossierNotification.exists?(notification.id)).to be_falsey
        end
      end
    end

    describe 'remind' do
      before do
        allow(AvisMailer).to receive(:avis_invitation_and_confirm_email).and_return(double(deliver_later: nil))
      end
      context 'without question' do
        it 'sends a reminder to the expert' do
          patch :remind, params: { procedure_id: procedure.id, id: pending_avis.id, statut: 'a-suivre' }
          expect(AvisMailer).to have_received(:avis_invitation_and_confirm_email)
          expect(flash.notice).to eq("Un mail de relance a été envoyé à #{pending_avis.expert.email}")
          expect(pending_avis.reload.reminded_at).to be_present
        end
      end

      context 'with question' do
        let!(:avis_with_question) { create(:avis, dossier:, claimant: instructeur, experts_procedure: experts_procedures.default, question_label: '123') }

        it 'sends a reminder to the expert' do
          patch :remind, params: { procedure_id: procedure.id, id: avis_with_question.id, statut: 'a-suivre' }
          expect(AvisMailer).to have_received(:avis_invitation_and_confirm_email)
          expect(flash.notice).to eq("Un mail de relance a été envoyé à #{avis_with_question.expert.email}")
          expect(avis_with_question.reload.reminded_at).to be_present
        end
      end

      context 'CSRF protection: GET no longer routes to remind' do
        it 'GET /remind is not routable' do
          expect(get: remind_instructeur_avis_path(procedure, 'a-suivre', pending_avis)).not_to be_routable
        end

        it 'PATCH /remind is routable' do
          expect(patch: remind_instructeur_avis_path(procedure, 'a-suivre', pending_avis)).to be_routable
        end
      end
    end
  end

  context 'without a signed in user' do
    it 'redirects to the sign in page' do
      patch :revoquer, params: { procedure_id: procedures.individual.id, id: avis.pending.id, statut: 'a-suivre' }

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
