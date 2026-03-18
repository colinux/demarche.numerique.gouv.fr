# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::Client do
  let(:service) { described_class.new }
  let(:payload) { { event: { state: "accepte" } } }
  let(:api_client) { instance_double(API::Client) }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("AMI_API_URL", nil).and_return("https://ami.example.org")
    allow(ENV).to receive(:fetch).with("AMI_API_USER", nil).and_return("ami-user")
    allow(ENV).to receive(:fetch).with("AMI_API_PASSWORD", nil).and_return("ami-password")
    allow(API::Client).to receive(:new).and_return(api_client)
  end

  it 'returns success when API call succeeds' do
    allow(api_client).to receive(:call).and_return(
      Dry::Monads::Success({ body: { ok: true } })
    )

    result = service.send_notification(payload)

    expect(api_client).to have_received(:call).with(
      url: URI("https://ami.example.org/api/v1/notifications"),
      json: payload,
      method: :post,
      userpwd: "ami-user:ami-password"
    )
    expect(result).to be_success
  end

  it 'returns failure when API returns 4xx' do
    allow(api_client).to receive(:call).and_return(
      Dry::Monads::Failure({ code: 400, reason: "Bad request", retryable: false })
    )

    result = service.send_notification(payload)

    expect(result).to be_failure
    expect(result.failure.retryable).to be(false)
  end

  it 'returns retryable failure when API times out' do
    timeout_error = API::Client::HTTPError.new(
      double(
        effective_url: "https://ami.example.org/api/v1/notifications",
        code: 0,
        body: "",
        return_message: "Operation timed out",
        total_time: 5.0,
        connect_time: 1.0,
        headers: {}
      )
    )
    allow(api_client).to receive(:call).and_return(
      Dry::Monads::Failure({ code: 0, reason: timeout_error, retryable: true })
    )

    result = service.send_notification(payload)

    expect(result).to be_failure
    expect(result.failure.retryable).to be(true)
  end
end
