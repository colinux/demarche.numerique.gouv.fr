# frozen_string_literal: true

# Sentry hook dropping the arguments of a mail delivery job: a live token sits
# there, and `send_default_pii` governs only what the SDK collects on its own.
#
# sentry-sidekiq reports the Redis payload as the context and repeats it as raw
# JSON in `jobstr`; sentry-rails reports the deserialized arguments in the
# extras, on any queue adapter but Sidekiq.
module SentryJobArguments
  ARGUMENTS_KEY = 'arguments'
  MAIL_DELIVERY_JOB = PriorizedMailDeliveryJob.name

  def self.scrub(event)
    event.extra.delete(:arguments) if event.extra[:active_job] == MAIL_DELIVERY_JOB

    sidekiq = event.contexts[:sidekiq]
    return event if sidekiq.nil?

    sidekiq.delete(:jobstr)
    sidekiq['args'] = scrub_arguments(sidekiq['args']) if sidekiq.key?('args')

    event
  end

  def self.scrub_arguments(payload)
    case payload
    when Hash
      if payload['job_class'] == MAIL_DELIVERY_JOB
        payload.except(ARGUMENTS_KEY)
      else
        payload.transform_values { scrub_arguments(it) }
      end
    when Array then payload.map { scrub_arguments(it) }
    else payload
    end
  end
end
