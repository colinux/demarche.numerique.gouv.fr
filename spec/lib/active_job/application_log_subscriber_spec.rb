# frozen_string_literal: true

describe ActiveJob::ApplicationLogSubscriber do
  let(:output) { StringIO.new }

  before { allow(Lograge).to receive(:logger).and_return(ActiveSupport::Logger.new(output)) }

  def logged_args(job)
    event = ActiveSupport::Notifications::Event.new('enqueue.active_job', Time.current, Time.current, SecureRandom.hex, { job: })
    described_class.new.enqueue(event)

    JSON.parse(output.string)['job_args']
  end

  it 'logs which mail goes to which record, but not the token next to it' do
    user = users.usager
    job = PriorizedMailDeliveryJob.new('DeviseUserMailer', 'reset_password_instructions', 'deliver_now', args: [user, 'a-live-reset-token'])

    expect(logged_args(job)).to eq([
      'DeviseUserMailer', 'reset_password_instructions', 'deliver_now',
      { 'args' => [user.to_global_id.to_s, '[FILTERED]'] },
    ])
  end

  # The cost of filtering mail delivery jobs only: the real AMI payload keeps
  # its FranceConnect identity hash and the name of the usager in the log.
  it 'keeps the strings nested in the payload of a job that is not a mailer' do
    payload = { item_id: '42', content_link: 'https://demarches.gouv.fr/dossiers/42' }
    job = Ami::SendNotificationJob.new(payload, { dossier: 42 })

    expect(logged_args(job).first).to eq(payload.stringify_keys)
  end
end
