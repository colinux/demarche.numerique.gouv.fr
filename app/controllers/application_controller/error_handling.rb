# frozen_string_literal: true

module ApplicationController::ErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from ActionController::InvalidAuthenticityToken do
      retry_url = request.format.html? ? csrf_retry_redirect_url : nil

      if retry_url
        redirect_to retry_url
      else
        render file: Rails.public_path.join('403.html'), layout: false, status: :forbidden
      end
    end

    rescue_from ActionView::MissingTemplate do |exception|
      if request.format.html? || request.format.turbo_stream?
        raise exception
      else
        head :not_acceptable
      end
    end
  end

  private

  # A stale CSRF token (page kept open until the token rotated, or restored from
  # the bfcache) makes a state-changing POST fail. Redirecting to the referer in
  # GET re-renders a page with a fresh token and cookie so the user can retry; the
  # csrf_retry flag caps it to a single retry before falling back to the 403 page.
  def csrf_retry_redirect_url
    return if !user_signed_in?
    return if request.referer.blank?

    referer_uri = URI.parse(request.referer)

    return unless referer_uri.scheme == request.scheme
    return unless referer_uri.host == request.host
    return unless referer_uri.port == request.port

    params = Rack::Utils.parse_nested_query(referer_uri.query)
    return if params['csrf_retry'] == '1'

    params['csrf_retry'] = '1'
    referer_uri.query = params.to_query
    referer_uri.to_s
  rescue URI::InvalidURIError
    nil
  end
end
