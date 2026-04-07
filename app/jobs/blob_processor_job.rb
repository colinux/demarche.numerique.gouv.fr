# frozen_string_literal: true

class BlobProcessorJob < ApplicationJob
  queue_as do
    blob = self.arguments.first
    attachment = blob&.attachments&.includes(:record)&.first

    if ocr_compatible?(attachment&.record)
      :default # UI is waiting for OCR result
    else
      :low # thumbnails and watermarks can wait
    end
  end

  discard_on ActiveRecord::RecordNotFound
  discard_on ActiveStorage::FileNotFoundError
  discard_on ActiveRecord::InvalidForeignKey

  retry_on(ActiveStorage::IntegrityError, attempts: 5, wait: 5.seconds) do |job, _error|
    blob = job.arguments.first
    blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::INTEGRITY_ERROR, virus_scanned_at: Time.current)
  end

  retry_on "Vips::Error", attempts: 3 # not as const because vips is loaded at runtime
  retry_on WatermarkService::Error, attempts: 3

  rescue_from ActiveStorage::PreviewError do |exception|
    retry_or_discard(exception)
  end

  attr_reader :blob, :attachment

  def perform(blob)
    require "vips"

    @blob = blob
    return if blob.nil?
    # Idempotency guard: during deployment, old VirusScannerJob/ImageProcessorJob may
    # overlap with new BlobProcessorJob for the same blob. Skip if already processed.
    return if blob.metadata["processed"]

    @attachment = blob.attachments.includes(:record).first

    processable = blob.content_type.in?(PROCESSABLE_TYPES)

    # Phase 1: Virus scan + image mutations in a single blob.open to minimize downloads
    blob.open do |tempfile|
      scan_virus(tempfile) if !blob.virus_scanner.done?

      if attachment && blob.virus_scanner.safe? && processable && needs_mutations?
        apply_mutations(tempfile)
      end
    end

    return mark_processed if !blob.virus_scanner.safe?
    return mark_processed if attachment.nil?

    # Phase 2: OCR (external API call)
    add_ocr_data

    # Phase 3: Representations (ActiveStorage manages its own downloads)
    create_representations if blob.representation_required?

    mark_processed
  end

  private

  def scan_virus(tempfile)
    if ClamavService.safe_file?(tempfile.path)
      blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::SAFE, virus_scanned_at: Time.current)
    else
      blob.update_columns(virus_scan_result: ActiveStorage::VirusScanner::INFECTED, virus_scanned_at: Time.current)
    end
  end

  def apply_mutations(tempfile)
    require "vips"
    modified = false
    current_file = tempfile
    extra_tempfiles = []

    if jpeg?
      output = Tempfile.new(["rotated", File.extname(current_file)])
      extra_tempfiles << output
      processed = AutoRotateService.new.process(current_file, output)
      if processed
        current_file = processed
        modified = true
      end
    end

    if blob.content_type == "image/png" && embeddable_in_pdf?
      # UninterlaceService modifies the file in-place (writes to the same path then reopens)
      processed = UninterlaceService.new.process(current_file)
      modified = true if processed
    end

    if blob.watermark_pending?
      output = Tempfile.new(["watermarked", File.extname(current_file)])
      extra_tempfiles << output
      processed = WatermarkService.new.process(current_file, output)
      if processed
        current_file = processed
        modified = true
        blob.watermarked_at = Time.current
      end
    end

    if modified
      blob.upload(current_file)
      blob.save!
    end
  ensure
    extra_tempfiles.each do |f|
      f.close
      f.unlink if File.exist?(f.path)
    end
  end

  def needs_mutations?
    return true if jpeg?
    return true if blob.content_type == "image/png" && embeddable_in_pdf?
    return true if blob.watermark_pending?

    false
  end

  def jpeg?
    blob.content_type.in?(["image/jpeg", "image/jpg"])
  end

  def embeddable_in_pdf?
    attachment.name.in?(%w[logo signature]) &&
      attachment.record_type.in?(%w[AttestationTemplate GroupeInstructeur])
  end

  def create_representations
    blob.attachments.each do |att|
      next if !att.representable?
      att.representation(resize_to_limit: [400, 400]).processed
      if att.blob.content_type.in?(RARE_IMAGE_TYPES)
        att.variant(resize_to_limit: [2000, 2000]).processed
      end
      if att.record.class == ActionText::RichText
        att.variant(resize_to_limit: [1024, 768]).processed
      end
    end
  end

  def add_ocr_data
    champ = attachment.record
    return if !ocr_compatible?(champ)
    return if !champ.may_fetch?

    champ.fetch!
  end

  def ocr_compatible?(maybe_champ)
    return false if !maybe_champ.is_a?(Champs::PieceJustificativeChamp)

    maybe_champ.ocr_compatible?
  end

  def mark_processed
    if !blob.metadata["processed"]
      blob.metadata["processed"] = true
      blob.save!
    end
  end

  def retry_or_discard(exception)
    if executions < 3
      retry_job wait: 5.minutes, error: exception
    end
  end
end
