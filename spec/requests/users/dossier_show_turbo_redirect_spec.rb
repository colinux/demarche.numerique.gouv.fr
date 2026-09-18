# frozen_string_literal: true

describe 'Users::DossiersController#show after a Turbo form redirect', type: :request do
  # A Turbo-enabled POST form (data-turbo="true") is submitted with fetch and
  # `Accept: text/vnd.turbo-stream.html, text/html, application/xhtml+xml`; the
  # browser reuses that header when it follows the 303 back to the dossier page.
  # `respond_to` must pick html there, not the turbo_stream listed first.
  let(:turbo_accept) { 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml' }
  let(:user) { create(:user) }
  let(:procedure) { create(:procedure, :published, :accuse_lecture) }
  let!(:dossier) { create(:dossier, :accepte, procedure:, user:) }

  before { login_as(user, scope: :user) }

  it 'renders the html page' do
    get dossier_path(dossier), headers: { 'HTTP_ACCEPT' => turbo_accept }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/html')
  end

  it 'shows the decision after the accusé de lecture agreement' do
    referer = "http://#{host}#{dossier_path(dossier)}"
    post set_accuse_lecture_agreement_at_dossier_path(dossier), headers: { 'HTTP_ACCEPT' => turbo_accept, 'HTTP_REFERER' => referer }
    expect(response).to redirect_to(referer)

    get response.location, headers: { 'HTTP_ACCEPT' => turbo_accept }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('Accusé de lecture accepté')
    expect(dossier.reload.accuse_lecture_agreement_at).to be_present
  end
end
