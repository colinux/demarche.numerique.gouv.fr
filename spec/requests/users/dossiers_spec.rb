# frozen_string_literal: true

RSpec.describe 'Users::Dossiers', type: :request do
  describe 'POST #clone with a stale CSRF token', :allow_forgery_protection do
    let(:dossier) { dossiers.en_construction }

    before { login_as(dossier.user, scope: :user) }

    it 'redirects to the referer to refresh the token instead of cloning' do
      expect {
        post clone_dossier_path(dossier), headers: { 'HTTP_REFERER' => 'http://www.example.com/dossiers' }
      }.not_to change(dossier.user.dossiers, :count)

      expect(response).to redirect_to('http://www.example.com/dossiers?csrf_retry=1')
    end
  end
end
