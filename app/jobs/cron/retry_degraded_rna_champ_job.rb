# frozen_string_literal: true

class Cron::RetryDegradedRNAChampJob < Cron::RetryDegradedChampJob
  self.schedule_expression = "every 2 hours at minute 30"
  self.champ_class = Champs::RNAChamp
  self.health_provider = :djepva_association
end
