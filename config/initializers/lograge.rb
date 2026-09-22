# frozen_string_literal: true

# Same output as Lograge::Formatters::Logstash, without the logstash-event gem
class LogstashFormatter
  include Lograge::Formatters::Helpers::MethodAndPath

  def call(data)
    data.merge(
      '@timestamp' => Time.current.utc,
      '@version' => '1',
      'message' => "[#{data[:status]}]#{method_and_path_string(data)}(#{data[:controller]}##{data[:action]})"
    ).to_json
  end
end

Rails.application.configure do
  config.lograge.formatter = LogstashFormatter.new
  config.lograge.base_controller_class = ['ActionController::Base', 'Manager::ApplicationController']

  # This will allow to override custom options from environement file
  # injected by ansible.
  if !config.lograge.custom_options
    config.lograge.custom_options = lambda do |event|
      hash = {
        type: 'tps',
        source: ENV['SOURCE'],
        tags: ['request', event.payload[:exception] ? 'exception' : nil].compact,
        process: {
          pid: Process.pid,
        },
        db_queries: event.payload[:queries_count],
        db_queries_cached: event.payload[:cached_queries_count],
      }

      hash.merge!(event.payload[:to_log]) if event.payload.key?(:to_log)

      hash.compact
    end

    config.lograge.custom_payload do |controller|
      {
        xhr: !!controller&.request&.xhr?,
      }
    end
  end

  config.lograge.keep_original_rails_log = true
  config.lograge.logger = ActiveSupport::Logger.new(Rails.root.join('log', "logstash_#{Rails.env}.log"))
  config.lograge.ignore_actions = ['PingController#index']
end

Rails.application.config.after_initialize do |app|
  if app.config.lograge.enabled
    ActiveJob::ApplicationLogSubscriber.attach_to(:active_job)
  end
end
