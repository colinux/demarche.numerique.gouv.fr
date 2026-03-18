# frozen_string_literal: true

module Ami
  class Client
    include Dry::Monads[:result]

    def send_notification(payload)
      path = "/api/v1/notifications"

      result = API::Client.new.call(
        url: build_url(path),
        json: payload,
        method: :post,
        userpwd: "#{api_user}:#{api_password}"
      )
      handle_result(result)
    end

    def configured?
      api_url.present? && api_user.present? && api_password.present?
    end

    private

    def api_url = ENV.fetch("AMI_API_URL", nil)
    def api_user = ENV.fetch("AMI_API_USER", nil)
    def api_password = ENV.fetch("AMI_API_PASSWORD", nil)

    def build_url(path)
      uri = URI(api_url)
      uri.path = path
      uri
    end

    def handle_result(result)
      case result
      in Success(body:)
        Success(body)
      in Failure(code:, reason:, retryable:)
        Failure(API::Client::Error[:api_error, code, retryable, reason])
      end
    end
  end
end
