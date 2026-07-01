# frozen_string_literal: true

describe Administrateurs::MailTemplatesController, type: :controller do
  render_views
  let(:procedure) { create :procedure }

  let(:admin) { administrateurs(:default_admin) }

  before do
    sign_in(procedure.administrateurs.first.user)
  end

  describe 'GET index' do
    render_views

    subject { get :index, params: { procedure_id: procedure.id } }

    it '', :slow do
      expect(subject.status).to eq 200
      expect(subject.body).to include("Modèles d’email")
      expect(subject.body).to include(Mails::InitiatedMail::DISPLAYED_NAME)
    end
  end

  describe '#preview' do
    let(:procedure) { create(:procedure, :with_logo, :with_service, administrateur: admin) }

    before do
      sign_in(admin.user)
      get :preview, params: { id: "initiated_mail", procedure_id: procedure.id }
    end

    it { expect(response).to have_http_status(:ok) }

    it 'displays the procedure logo' do
      expect(response.body).to have_css("img[src*='/rails/active_storage/blobs/']")
    end

    it 'displays the action buttons' do
      expect(response.body).to have_link('Consulter mon dossier')
    end

    it 'displays the service in the footer' do
      expect(response.body).to include(procedure.service.nom)
      expect(response.body).to include(procedure.service.telephone)
    end
  end

  describe 'PUT #update (tiptap)' do
    let(:admin) { create(:administrateur) }
    let(:procedure) { create(:procedure, administrateur: admin) }
    let(:json_body) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Salut" }] }] }.to_json }
    let(:json_subject) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Objet" }] }] }.to_json }

    before { sign_in(admin.user) }

    it 'enregistre json_body et json_subject' do
      put :update, params: {
        procedure_id: procedure.id, id: 'received_mail',
        mails_received_mail: { tiptap_body: json_body, tiptap_subject: json_subject },
      }
      mail = procedure.reload.received_mail
      expect(mail.json_body).to eq(JSON.parse(json_body))
      expect(mail.json_subject).to eq(JSON.parse(json_subject))
    end
  end

  describe 'GET edit' do
    let(:admin) { create(:administrateur) }
    let(:procedure) { create(:procedure, administrateur: admin) }

    before { sign_in(admin.user) }

    subject { get :edit, params: { procedure_id: procedure.id, id: 'received_mail' } }

    it { expect(subject).to have_http_status(:ok) }

    it 'affiche l’éditeur d’objet en une ligne' do
      expect(subject.body).to include('data-tiptap-single-line-value')
    end

    it 'affiche l’aperçu du sujet et du corps' do
      expect(subject.body).to include('id="mail-body-preview"')
      expect(subject.body).to include('id="mail-subject-preview"')
    end
  end

  describe 'POST #preview (turbo_stream)' do
    let(:admin) { create(:administrateur) }
    let(:procedure) { create(:procedure, :published, administrateur: admin) }
    let(:json_body) { { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Salut" }] }] }.to_json }

    before { sign_in(admin.user) }

    it 'renvoie un turbo_stream mettant à jour l’aperçu du corps' do
      post :preview, params: {
        procedure_id: procedure.id, id: 'received_mail',
        mails_received_mail: { tiptap_body: json_body },
      }, format: :turbo_stream
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      expect(response.body).to include('mail-body-preview')
      expect(response.body).to include('Salut')
    end
  end
end
