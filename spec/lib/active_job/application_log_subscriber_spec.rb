# frozen_string_literal: true

describe ActiveJob::ApplicationLogSubscriber do
  let(:output) { StringIO.new }

  before { allow(Lograge).to receive(:logger).and_return(ActiveSupport::Logger.new(output)) }

  def logged_args(job)
    event = ActiveSupport::Notifications::Event.new('enqueue.active_job', Time.current, Time.current, SecureRandom.hex, { job: })
    described_class.new.enqueue(event)

    JSON.parse(output.string)['job_args']
  end

  it 'logs the records nested in the arguments of a mailer as global ids' do
    instructeur = instructeurs.default
    dossier = dossiers.en_construction
    job = PriorizedMailDeliveryJob.new('DossierMailer', 'notify_groupe_instructeur_changed', 'deliver_now', args: [instructeur, dossier])

    expect(logged_args(job)).to eq([
      'DossierMailer', 'notify_groupe_instructeur_changed', 'deliver_now',
      { 'args' => [instructeur.to_global_id.to_s, dossier.to_global_id.to_s] },
    ])
  end
end
