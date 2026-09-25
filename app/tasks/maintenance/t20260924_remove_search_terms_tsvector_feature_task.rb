# frozen_string_literal: true

module Maintenance
  class T20260924RemoveSearchTermsTsvectorFeatureTask < MaintenanceTasks::Task
    include RunnableOnDeployConcern

    run_on_first_deploy

    OBSOLETE_FEATURES = [
      :search_terms_tsvector,
    ].freeze

    def collection
      OBSOLETE_FEATURES
    end

    def process(feature_key)
      Flipper.remove(feature_key)
    end
  end
end
