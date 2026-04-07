# frozen_string_literal: true

class BlobProcessorJob < ApplicationJob
  queue_as do
    blob = self.arguments.first
    maybe_champ = blob&.attachments&.first&.record

    if ocr_compatible?(maybe_champ)
      :default # UI is waiting
    else
      :low # thumbnails and watermarks. Execution depends of virus scanner which is more urgent
    end
  end

  class FileNotScannedYetError < StandardError
  end

  # If by the time the job runs the blob has been deleted, ignore the error
  discard_on ActiveRecord::RecordNotFound

  # Safety net: if job is enqueued before virus scan completes, retry with short delay
  # This shouldn't happen normally since VirusScannerJob now enqueues ImageProcessorJob
  retry_on FileNotScannedYetError, wait: 10.seconds, attempts: 5
  # If the file is deleted during the scan, ignore the error
  discard_on ActiveStorage::FileNotFoundError
  discard_on ActiveRecord::InvalidForeignKey

  retry_on "Vips::Error", attempts: 3 # not as const because we don't load vips at load time
  retry_on WatermarkService::Error, attempts: 3

  rescue_from ActiveStorage::PreviewError do |exception|
    retry_or_discard(exception)
  end

  def perform(blob)
    require "vips" # load at runtime, not at bootime because vips is available only in jobs

    return if blob.nil?
    raise FileNotScannedYetError if blob.virus_scanner.pending?
    return if ActiveStorage::Attachment.find_by(blob_id: blob.id)&.record_type == "ActiveStorage::VariantRecord"

    add_ocr_data(blob)
    auto_rotate(blob) if ["image/jpeg", "image/jpg"].include?(blob.content_type)
    uninterlace(blob) if blob.content_type == "image/png" && embeddable_in_pdf?(blob)
    create_representations(blob) if blob.representation_required?
    add_watermark(blob) if blob.watermark_pending?
  rescue Vips::Error => e
    Rails.logger.info "ImageProcessorJob raising vips error: #{e.message}"
  end

  private

  def auto_rotate(blob)
    blob.open do |file|
      Tempfile.create(["rotated", File.extname(file)]) do |output|
        processed = AutoRotateService.new.process(file, output)
        return if processed.blank?

        blob.upload(processed) # also update checksum & byte_size accordingly
        blob.save!
      end
    end
  end

  def uninterlace(blob)
    blob.open do |file|
      processed = UninterlaceService.new.process(file)
      return if processed.blank?

      blob.upload(processed)
      blob.save!
    end
  end

  def embeddable_in_pdf?(blob)
    blob.attachments.any? do |attachment|
      attachment.name.in?(%w[logo signature]) &&
        attachment.record_type.in?(%w[AttestationTemplate GroupeInstructeur])
    end
  end

  def create_representations(blob)
    blob.attachments.each do |attachment|
      next unless attachment&.representable?
      attachment.representation(resize_to_limit: [400, 400]).processed
      if attachment.blob.content_type.in?(RARE_IMAGE_TYPES)
        attachment.variant(resize_to_limit: [2000, 2000]).processed
      end
      if attachment.record.class == ActionText::RichText
        attachment.variant(resize_to_limit: [1024, 768]).processed
      end
    end
  end

  def add_watermark(blob)
    return if blob.watermark_done?

    blob.open do |file|
      Tempfile.create(["watermarked", File.extname(file)]) do |output|
        processed = WatermarkService.new.process(file, output)
        return if processed.blank?

        blob.upload(processed) # also update checksum & byte_size accordingly
        blob.watermarked_at = Time.current
        blob.save!
      end
    end
  end

  def add_ocr_data(blob)
    champ = blob&.attachments&.first&.record
    return if !ocr_compatible?(champ)
    return if !champ.may_fetch? # a previous blob may have already been analyzed

    champ.fetch!
  end

  def ocr_compatible?(maybe_champ)
    return false if !maybe_champ.is_a?(Champs::PieceJustificativeChamp)

    maybe_champ.ocr_compatible?
  end

  def retry_or_discard(exception)
    if executions < 3
      retry_job wait: 5.minutes, error: exception
    end
  end
end
