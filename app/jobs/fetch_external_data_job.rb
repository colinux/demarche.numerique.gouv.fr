# frozen_string_literal: true

class FetchExternalDataJob < ApplicationJob
  discard_on ActiveJob::DeserializationError
  queue_as :critical # ui feedback, asap

  retry_on RetryableFetchError, attempts: 3, wait: :polynomially_longer do |job, err|
    record = job.arguments.first
    record.external_data_error!

    # Don't raise, otherwise it will pop forever as "working" queue without doing anything.
    # The wrapper carries the provider SentryFingerprint groups the outage by.
    Sentry.capture_exception(err)
  end

  def perform(record, external_id)
    return if record.external_id != external_id
    # waiting_for_job on a first fetch, waiting_for_fix on a cron retry.
    return if !record.may_fetch?

    Sentry.set_tags(record.external_data_sentry_tags)
    Sentry.set_extras(external_id:)

    record.fetch!
  end
end
