# frozen_string_literal: true

class ErrorsController < ApplicationController
  rescue_from StandardError do |exception|
    Sentry.capture_exception(exception)
    # catch any error, except errors triggered by middlewares outside controller (like warden middleware)
    render file: Rails.public_path.join('500.html'), layout: false, status: :internal_server_error
  end

  def internal_server_error
    # This dynamic template is rendered when a "normal" error occurs, (ie. a bug which is 99.99% of errors.)
    # However if this action fails (error in the view or in a middlewares)
    # the exceptions are rescued and a basic 100% static html file is rendererd instead.
    render_error 500
  end

  def not_found = render_error 404

  def unprocessable_entity
    # ErrorsController is mounted via `config.exceptions_app = self.routes`, so the
    # session and flash middlewares are bypassed here and `flash` is unavailable.
    # csrf_retry_redirect_url carries the retry intent through a query param instead,
    # which ApplicationController#display_csrf_retry_message turns into a flash on the
    # refreshed page.
    retry_url = csrf_retry_redirect_url

    if retry_url
      redirect_to retry_url
    else
      render_error 422
    end
  end

  def show # generic page for others errors
    @status = params[:status].to_i
    @error_name = Rack::Utils::HTTP_STATUS_CODES[@status]

    render_error @status
  end

  # Intercept errors in before_action when fetching user or roles
  # when db is unreachable so we can still display a nice 500 static page
  def current_user
    super
  rescue
    nil
  end

  def current_user_roles
    super
  rescue
    nil
  end

  private

  def render_error(status)
    respond_to do |format|
      format.html { render status: }
      format.json { render status:, json: { status:, name: Rack::Utils::HTTP_STATUS_CODES[status] } }
    end
  end
end
