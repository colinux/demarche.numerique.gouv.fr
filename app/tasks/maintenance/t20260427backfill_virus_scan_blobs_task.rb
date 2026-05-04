# frozen_string_literal: true

module Maintenance
  class T20260427backfillVirusScanBlobsTask < MaintenanceTasks::Task
    # Traite le stock de blobs bloqués en virus_scan_result "pending".
    # Le CRON FixMissingAntivirusAnalysisJob gère le flux (blobs récents),
    # cette tâche gère le stock (backlog ancien).
    #
    # Inclut les orphelins (sans attachment) : BlobProcessorJob les marquera
    # simplement comme processed, et PurgeUnattachedBlobsJob les purgera.
    # On évite ainsi le semi-join sur 103M attachments qui timeout.
    #
    # On itère via Blob.in_batches (sans filtre WHERE) puis on applique le
    # filtre virus_scan_result dans process() sur le batch déjà borné par
    # ids. Itérer directement sur where(virus_scan_result: PENDING) timeout :
    # avec ~7M lignes pending sur 100M, le cursor `ORDER BY id LIMIT N`
    # avec ce filtre est trop coûteux si les pending sont concentrés sur
    # une plage d'ids (PG parcourt l'index PK en filtrant et peut traverser
    # des dizaines de millions de lignes avant d'en trouver N).
    #
    # Pour ne pas saturer la queue low ni Redis, le backfill
    # est découpé en tranches d'IDs (param `id_start`) et chaque BlobProcessorJob
    # est planifié avec un wait_until aléatoire qui cible majoritairement les
    # heures creuses (nuit + weekend), avec un peu de débordement diurne.
    # À lancer successivement avec id_start = 0, 20_000_000, …, 200_000_000.
    #
    # Calibrage (last id ≈ 200M, ~7M pending sur 144M blobs ≈ 3.5% des IDs) :
    # - une tranche de 20M IDs ≈ 700k jobs enqueued = ~500 MB Redis au pic
    # - les variant blobs (preview, sans attachment) sortent vite
    #   (download + clamav), accélérant le throughput moyen
    # - fenêtre creuse = weekend complet + semaine 19h-8h, soit ~113h/168h
    # - sur 7j : ~113h creuses absorbent 85% des jobs (~5.3k/h sous une
    #   capacité ~30k/h) ; ~55h diurnes (semaine 8h-19h) absorbent 15%
    #   (~1.9k/h sous ~2-3k/h de headroom réel) — flux normal préservé

    BATCH_SIZE_IDS = 20_000_000
    BATCH_SPREAD_DAYS = 7
    OFFPEAK_TARGET_SHARE = 0.85

    attribute :id_start, :integer
    validates :id_start, presence: true, numericality: { greater_than_or_equal_to: 0 }

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    def collection
      ActiveStorage::Blob
        .where(id: id_start..(id_start + BATCH_SIZE_IDS))
        .in_batches(of: 10_000)
    end

    def process(batch)
      batch
        .where(virus_scan_result: ActiveStorage::VirusScanner::PENDING)
        .find_each do |blob|
          next if blob.metadata["processed"]

          BlobProcessorJob
            .set(wait_until: random_wait_until)
            .perform_later(blob)
        end
    end

    private

    def random_wait_until
      want_offpeak = rand < OFFPEAK_TARGET_SHARE
      loop do
        t = Time.current + rand(0...BATCH_SPREAD_DAYS.days.to_i)
        return t if offpeak?(t) == want_offpeak
      end
    end

    def offpeak?(time)
      time.saturday? || time.sunday? || time.hour >= 19 || time.hour < 8
    end
  end
end
