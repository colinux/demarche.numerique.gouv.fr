# frozen_string_literal: true

describe SentryJobArguments do
  let(:token) { 'a-live-reset-token' }
  let(:mail) { PriorizedMailDeliveryJob.new('DeviseUserMailer', 'reset_password_instructions', 'deliver_now', args: [token]).serialize }
  let(:event) { Sentry::ErrorEvent.new(configuration: Sentry.configuration) }

  # Both integrations report the Redis payload of the running job under
  # `sidekiq`, the job itself sitting in `args`.
  def scrubbed_sidekiq(context)
    event.contexts[:sidekiq] = context

    described_class.scrub(event).contexts[:sidekiq]
  end

  describe '.scrub' do
    it 'drops the arguments of a mail, and nothing else of it' do
      expect(scrubbed_sidekiq({ 'args' => [mail] })['args']).to eq([mail.except('arguments')])
    end

    it 'keeps the arguments of a job that is not a mail' do
      web_hook = WebHookJob.new(1, 42, 'en_construction', Time.current).serialize

      expect(scrubbed_sidekiq({ 'args' => [web_hook] })['args']).to eq([web_hook])
    end

    it 'drops the raw payload Sidekiq hands its error handlers' do
      error_context = Sentry::Sidekiq::ContextFilter.new({ job: { 'args' => [mail] }, jobstr: 'the same payload, as raw JSON' }).filtered

      expect { scrubbed_sidekiq(error_context) }.to change { error_context.key?(:jobstr) }.to(false)
    end

    it 'drops the arguments of a mail reported on another queue adapter' do
      event.extra = { active_job: 'PriorizedMailDeliveryJob', arguments: [token] }

      expect(described_class.scrub(event).extra).not_to have_key(:arguments)
    end
  end

  # No DSN in test: the client runs the hooks and skips the transport.
  describe 'wiring' do
    it 'scrubs an error event' do
      event.contexts[:sidekiq] = { 'args' => [mail] }

      sent = Sentry.get_current_client.send_event(event, { exception: Redis::CannotConnectError.new('Connection refused') })

      expect(sent.contexts[:sidekiq]['args']).to eq([mail.except('arguments')])
    end

    it 'scrubs a transaction event, which never reaches before_send' do
      transaction = Sentry::Transaction.new(name: 'Sidekiq/PriorizedMailDeliveryJob', op: 'queue.process')
      transaction.finish
      transaction_event = Sentry::TransactionEvent.new(configuration: Sentry.configuration, transaction:)
      transaction_event.contexts[:sidekiq] = { 'args' => [mail] }

      sent = Sentry.get_current_client.send_event(transaction_event)

      expect(sent.contexts[:sidekiq]['args']).to eq([mail.except('arguments')])
    end
  end
end
