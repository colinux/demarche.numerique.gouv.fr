# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ami::SendNotificationJob, type: :job do
  let(:client) { instance_double(Ami::Client, send_notification: result) }
  let(:payload) { { item_type: "dossier", item_id: "42", recipient_fc_hash: "abc123" } }
  let(:context) { { procedure_id: 12, dossier_id: 42, state: :en_instruction } }
  let(:result) { Dry::Monads::Success({ ok: true }) }

  before do
    allow(Ami::Client).to receive(:new).and_return(client)
  end

  it 'sends payload' do
    described_class.perform_now(payload, context)

    expect(client).to have_received(:send_notification).with(payload)
  end

  it 'captures and swallows non-retryable errors' do
    non_retryable_error = API::Client::Error[:api_error, 400, false, StandardError.new("Invalid payload")]
    allow(client).to receive(:send_notification).and_return(Dry::Monads::Failure(non_retryable_error))
    allow(Sentry).to receive(:capture_exception)

    expect { described_class.perform_now(payload, context) }.not_to raise_error
    expect(Sentry).to have_received(:capture_exception).with(instance_of(RuntimeError), anything).once
  end
end
