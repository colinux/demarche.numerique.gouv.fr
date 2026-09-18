# frozen_string_literal: true

RSpec.describe PriorizedMailDeliveryJob, type: :job do
  it 'does not print what a mail is handed in the Rails log' do
    output = StringIO.new
    allow(ActiveJob::Base).to receive(:logger).and_return(ActiveSupport::Logger.new(output))

    described_class.perform_later('DeviseUserMailer', 'reset_password_instructions', 'deliver_now', args: [users.usager, 'a-live-reset-token'])

    expect(output.string).to include('Enqueued PriorizedMailDeliveryJob')
    expect(output.string).not_to include('a-live-reset-token')
  end
end
