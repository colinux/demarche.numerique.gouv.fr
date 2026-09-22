# frozen_string_literal: true

class Procedure::EstimatedDelayComponent < ApplicationComponent
  delegate :distance_of_time_in_words, to: :helpers

  def initialize(procedure:, fallback_to_placeholder: false)
    @procedure = procedure
    @fallback_to_placeholder = fallback_to_placeholder
    @fastest, @mean, @slow = @procedure.stats_usual_traitement_time
  end

  def estimation_present?
    @fastest && @mean && @slow
  end

  def placeholder_mode?
    !estimation_present? && @procedure.brouillon?
  end

  def render?
    return false if @procedure.declarative_accepte?
    return false if !@procedure.estimated_processing_duration_visible?
    return true if estimation_present?

    if @fallback_to_placeholder
      placeholder_mode?
    else
      false
    end
  end

  def placeholder_estimation(key)
    tag.span(t(key), class: 'fr-text-default--info')
  end

  def cleaned_nearby_estimation(&block)
    if placeholder_mode?
      yield(placeholder_estimation('.placeholder_delay'), 'fast_html')
      yield(placeholder_estimation('.placeholder_delay_mean'), 'mean_html')
      yield(placeholder_estimation('.placeholder_delay_mean'), 'slow_html')
    else
      [@fastest, @mean, @slow]
        .map { distance_of_time_in_words(_1) }
        .uniq
        .zip(['fast_html', 'mean_html', 'slow_html'])
        .each do |estimation, i18n_key|
          yield(estimation, i18n_key)
        end
    end
  end
end
