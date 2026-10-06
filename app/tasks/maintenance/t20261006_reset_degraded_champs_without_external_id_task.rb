# frozen_string_literal: true

module Maintenance
  class T20261006ResetDegradedChampsWithoutExternalIdTask < MaintenanceTasks::Task
    def collection
      ChampData.degraded.where(external_id: [nil, ''])
    end

    def process(champ)
      return if !champ.degraded? || champ.read_attribute(:external_id).present?

      champ.update_columns(external_state: nil, fetch_external_data_exceptions: [])
    end
  end
end
