# frozen_string_literal: true

class Cron::RetryDegradedSiretChampJob < Cron::RetryDegradedChampJob
  self.schedule_expression = "every 2 hours"
  self.champ_class = Champs::SiretChamp
  self.health_provider = :insee_sirene
end
