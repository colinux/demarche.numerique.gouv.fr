# frozen_string_literal: true

class Cron::FixMissingAntivirusAnalysisJob < Cron::CronJob
  self.schedule_expression = "every day at 01:45"

  def perform
    blobs_to_skip = ActiveStorage::Attachment
      .where(record_type: "ActiveStorage::VariantRecord")
      .or(ActiveStorage::Attachment.where(name: "preview_image"))
      .select(:blob_id)

    ActiveStorage::Blob
      .where(virus_scan_result: ActiveStorage::VirusScanner::PENDING)
      .where.not(id: blobs_to_skip)
      .find_each do |blob|
        BlobProcessorJob.perform_later(blob)
      end
  end
end
