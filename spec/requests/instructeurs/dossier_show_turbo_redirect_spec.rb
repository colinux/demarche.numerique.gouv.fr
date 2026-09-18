# frozen_string_literal: true

describe 'Instructeurs::DossiersController#show after a Turbo form redirect', type: :request do
  # Same negotiation trap as the usager page: the GET that follows a Turbo POST
  # form's 303 carries `Accept: text/vnd.turbo-stream.html, text/html, ...`.
  let(:turbo_accept) { 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml' }
  let(:instructeur) { create(:instructeur) }
  let(:procedure) { create(:procedure, :published, :for_individual, instructeurs: [instructeur]) }
  let(:dossier) { create(:dossier, :en_instruction, :with_individual, procedure:) }

  before { login_as(instructeur.user, scope: :user) }

  it 'renders the html page' do
    get instructeur_dossier_path(procedure, dossier), headers: { 'HTTP_ACCEPT' => turbo_accept }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/html')
  end
end
