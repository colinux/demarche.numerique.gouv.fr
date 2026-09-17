# frozen_string_literal: true

class PriorizedMailDeliveryJob < ActionMailer::MailDeliveryJob
  # Rails prints job arguments on every enqueue and every run, wherever the app
  # runs, and here they are a token.
  self.log_arguments = false

  discard_on ActiveJob::DeserializationError

  def queue_name
    mailer, action_name = @arguments
    if mailer.constantize.critical_email?(action_name)
      super
    else
      custom_queue
    end
  end

  def custom_queue
    'default'
  end
end
