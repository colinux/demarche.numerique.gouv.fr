# frozen_string_literal: true

module Maintenance
  class T20260728BackfillSearchTermsTsvectorTask < MaintenanceTasks::Task
    # Backfill the stored tsvector columns added by
    # AddSearchTermsTsvectorToDossiers.
    #
    # Computed entirely in SQL from the existing text columns, so no champ,
    # etablissement or individual is reloaded: each batch is a single UPDATE.
    # Rows whose text columns were never populated end up with an empty tsvector
    # rather than NULL, which matches nothing — same as before — and keeps them
    # out of the collection on a rerun.
    #
    # The search reads only these columns: dossiers not reindexed since they
    # were added stay unfindable until this completes.

    include RunnableOnDeployConcern

    run_on_first_deploy

    BATCH_SIZE = 1_000

    def collection
      Dossier
        .where(search_terms_tsvector: nil)
        .in_batches(of: BATCH_SIZE)
    end

    def process(batch)
      batch.update_all(<<~SQL.squish)
        search_terms_tsvector =
          to_tsvector('french_unaccent', COALESCE(search_terms, '')),
        all_search_terms_tsvector =
          to_tsvector('french_unaccent', COALESCE(search_terms, '') || ' ' || COALESCE(private_search_terms, ''))
      SQL
    end
  end
end
