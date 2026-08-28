# frozen_string_literal: true

RSpec.describe ApplicationController::ErrorHandling, type: :controller do
  controller(ActionController::Base) do
    include ApplicationController::ErrorHandling

    def user_signed_in? = false

    def invalid_authenticity_token
      raise ActionController::InvalidAuthenticityToken
    end

    def show
      render template: 'nonexistent/template'
    end
  end

  before do
    routes.draw do
      post 'invalid_authenticity_token' => 'anonymous#invalid_authenticity_token'
      get 'show' => 'anonymous#show'
    end
  end

  describe 'handling ActionController::InvalidAuthenticityToken' do
    context 'when the user is signed in and comes from a same-origin HTML page' do
      before do
        allow(controller).to receive(:user_signed_in?).and_return(true)
        request.env['HTTP_REFERER'] = 'http://test.host/dossiers'
      end

      it 'redirects to the referer with a csrf_retry flag so the token gets refreshed' do
        post :invalid_authenticity_token

        expect(response).to redirect_to('http://test.host/dossiers?csrf_retry=1')
      end

      context 'when the referer is already flagged (retry already attempted)' do
        before { request.env['HTTP_REFERER'] = 'http://test.host/dossiers?csrf_retry=1' }

        it 'renders the 403 page instead of looping' do
          post :invalid_authenticity_token

          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when the referer is on another origin' do
        before { request.env['HTTP_REFERER'] = 'http://elsewhere.example/dossiers' }

        it 'renders the 403 page' do
          post :invalid_authenticity_token

          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'when the request is not HTML (e.g. an API/fetch call)' do
        it 'renders the 403 page' do
          post :invalid_authenticity_token, format: :json

          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'when the user is not signed in' do
      before { request.env['HTTP_REFERER'] = 'http://test.host/users/sign_in' }

      it 'renders the 403 page' do
        post :invalid_authenticity_token

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when there is no referer' do
      before { allow(controller).to receive(:user_signed_in?).and_return(true) }

      it 'renders the 403 page' do
        post :invalid_authenticity_token

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'handling unsupported format requests' do
    it 'returns 406 for unsupported formats like zip' do
      get :show, format: :zip
      expect(response).to have_http_status(:not_acceptable)
    end

    it 'raises MissingTemplate for html format' do
      expect { get :show, format: :html }.to raise_error(ActionView::MissingTemplate)
    end

    it 'raises MissingTemplate for turbo_stream format' do
      expect { get :show, format: :turbo_stream }.to raise_error(ActionView::MissingTemplate)
    end
  end
end
