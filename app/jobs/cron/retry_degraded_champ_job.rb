# frozen_string_literal: true

class Cron::RetryDegradedChampJob < Cron::CronJob
  # They all went degraded within the same outage: spread them out, the champ
  # queue has no rate limiter of its own.
  SPREAD_OVER = 20.minutes

  # An outage leaves far more degraded champs than one run can replay without
  # flooding the pool. What is left over waits for the next run.
  BATCH_SIZE = 2_000

  class_attribute :champ_class, :health_provider
  class_attribute :spread_over, default: SPREAD_OVER
  class_attribute :batch_size, default: BATCH_SIZE

  # Abstract class: keeps `rake jobs:schedule` from registering this base,
  # which has no schedule_expression, in Sidekiq Cron.
  def self.schedulable?
    schedule_expression.present? && super
  end

  def perform(*args)
    return if !APIEntreprise::HealthChecker.provider_up?(health_provider)
    return if APIEntreprise::RateLimiter.throttled?(APIEntreprise::API::DEFAULT_POOL)

    retryable_batch.find_each do |champ|
      champ.fix_degraded!(wait: rand(0..spread_over)) if champ.may_fix_degraded?
    end
  end

  private

  def retryable_batch
    with_a_usable_token(degraded_champs)
      .limit(batch_size)
      .preload(dossier: :procedure)
  end

  def degraded_champs
    champ_class
      .degraded
      .joins(dossier: :procedure)
      .merge(Procedure.kept)
      .where(champs: { stream: Dossier::NON_HISTORY_STREAMS })
      .where(dossiers: { hidden_by_administration_at: nil, hidden_by_expired_at: nil })
  end

  # Whatever blocks the token blocks every retry it covers, so it is filtered
  # here rather than discovered champ by champ once the batch is already full.
  def with_a_usable_token(champs)
    champs = champs
      .where(procedures: { api_entreprise_token_rejected_at: [nil, ..Procedure::TOKEN_REJECTION_HOLDS_FOR.ago] })
      .where.not(procedures: { id: procedures_with_an_unusable_token })

    return champs if Procedure.instance_api_entreprise_token.usable?

    champs.where.not(procedures: { api_entreprise_token: nil })
  end

  # No SQL predicate decodes a JWT, so this one check stays in Ruby — over the
  # procedures carrying a token of their own, not over the degraded backlog.
  def procedures_with_an_unusable_token
    Procedure
      .where.not(api_entreprise_token: nil)
      .pluck(:id, :api_entreprise_token)
      .filter_map { |id, token| id if !APIEntrepriseToken.new(token).usable? }
  end
end
