# frozen_string_literal: true

class Cron::RetryDegradedDemandeurSiretJob < Cron::RetryDegradedExternalDataJob
  self.schedule_expression = "every 2 hours at minute 15"
  self.health_provider = :insee_sirene

  private

  def degraded_records
    DemandeurSiret
      .degraded
      .joins(dossier: :procedure)
      .merge(Procedure.kept)
      .where(dossiers: { hidden_by_administration_at: nil, hidden_by_expired_at: nil })
  end
end
