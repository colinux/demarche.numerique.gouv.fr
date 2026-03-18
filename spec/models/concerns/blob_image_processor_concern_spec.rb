# frozen_string_literal: true

describe BlobImageProcessorConcern do
  describe '#watermark_pending?' do
    context 'with legacy TitreIdentiteChamp' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :titre_identite }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, :en_construction, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'requires watermark' do
        champ.piece_justificative_file.attach(
          io: StringIO.new("image content"),
          filename: "identite.png",
          content_type: "image/png"
        )

        blob = champ.piece_justificative_file.attachments.first.blob

        expect(blob.watermark_pending?).to be true
      end
    end

    context 'with PieceJustificativeChamp with nature=TITRE_IDENTITE' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative, nature: 'TITRE_IDENTITE' }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, :en_construction, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'requires watermark' do
        champ.piece_justificative_file.attach(
          io: StringIO.new("image content"),
          filename: "identite.png",
          content_type: "image/png"
        )

        blob = champ.piece_justificative_file.attachments.first.blob

        expect(blob.watermark_pending?).to be true
      end
    end

    context 'with regular PieceJustificativeChamp (no nature)' do
      let(:procedure) { create(:procedure, :published, types_de_champ_public: [{ type: :piece_justificative }]) }
      let(:dossier) { create(:dossier, :with_populated_champs, :en_construction, procedure:) }
      let(:champ) { dossier.champs.first }

      it 'does not require watermark' do
        champ.piece_justificative_file.attach(
          io: StringIO.new("document content"),
          filename: "document.pdf",
          content_type: "application/pdf"
        )

        blob = champ.piece_justificative_file.attachments.first.blob

        expect(blob.watermark_pending?).to be false
      end
    end
  end
end
