# frozen_string_literal: true

class ClonePiecesJustificativesService
  def self.clone_attachments(original, kopy)
    case original
    when Champs::PieceJustificativeChamp
      clone_many_attachments(original, kopy, :piece_justificative_file)
    when TypeDeChamp
      clone_one_attachment(original, kopy, :piece_justificative_template)
      clone_one_attachment(original, kopy, :notice_explicative)
    when Procedure
      clone_one_attachment(original, kopy, :logo)
      clone_one_attachment(original, kopy, :notice)
      clone_one_attachment(original, kopy, :deliberation)
    when AttestationTemplate
      clone_one_attachment(original, kopy, :logo)
      clone_one_attachment(original, kopy, :signature)
    when Etablissement
      clone_one_attachment(original, kopy, :entreprise_attestation_sociale)
      clone_one_attachment(original, kopy, :entreprise_attestation_fiscale)
    when GroupeInstructeur
      clone_one_attachment(original, kopy, :signature)
    end
  end

  def self.clone_many_attachments(original, kopy, attachments_name)
    kopy_attachments = kopy.public_send(attachments_name)
    # Concurrent requests can both clone onto the same champ (e.g. parallel
    # multi-file uploads upserting the same buffer stream champ): skip blobs
    # already attached instead of violating the attachments unique index.
    already_attached_blob_ids = kopy_attachments.attachments.map(&:blob_id)

    original.public_send(attachments_name).attachments.each do |attachment|
      next if attachment.blob_id.in?(already_attached_blob_ids)

      begin
        kopy_attachments.attach(attachment.blob)
      rescue ActiveRecord::RecordNotUnique
        kopy.reload
      end
    end
  end

  def self.clone_one_attachment(original, kopy, attachment_name)
    attachment = original.public_send(attachment_name)
    if attachment.attached?
      kopy.public_send(attachment_name).attach(attachment.blob)
    end
  end
end
