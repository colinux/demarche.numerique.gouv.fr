# frozen_string_literal: true

describe ClonePiecesJustificativesService do
  describe '.clone_attachments with a type de champ' do
    let(:original) { create(:type_de_champ_explication) }
    let(:kopy) { original.dup }

    before { original.notice_explicative.attach(io: StringIO.new("notice"), filename: "notice.txt", content_type: "text/plain") }

    it 'clones the notice explicative to the copy' do
      described_class.clone_attachments(original, kopy)
      kopy.save!

      expect(kopy.notice_explicative.attachment).not_to eq(original.notice_explicative.attachment)
      expect(kopy.notice_explicative.blob).to eq(original.notice_explicative.blob)
    end
  end

  describe '.clone_attachments with a piece justificative champ' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :piece_justificative }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:original) { dossier.champ_data.first }
    let(:kopy) do
      original.dup.tap do
        it.stream = Dossier::USER_BUFFER_STREAM
        it.save!
      end
    end

    it 'clones attachments to the copy' do
      expect { described_class.clone_attachments(original, kopy) }
        .to change { kopy.piece_justificative_file.attachments.count }.from(0).to(1)
    end

    context 'when a blob is already attached to the copy' do
      before { kopy.piece_justificative_file.attach(original.piece_justificative_file.attachments.first.blob) }

      it 'skips it instead of raising RecordNotUnique' do
        expect { described_class.clone_attachments(original, kopy) }.not_to raise_error
        expect(kopy.reload.piece_justificative_file.attachments.count).to eq(1)
      end
    end

    context 'when a concurrent request attaches the same blob after the association is loaded' do
      it 'recovers instead of raising RecordNotUnique (RAILS-KJH)' do
        blob = original.piece_justificative_file.attachments.first.blob
        kopy.piece_justificative_file.attachments.load

        # a concurrent request cloning the same champ attaches the blob behind our back
        ChampData.find(kopy.id).piece_justificative_file.attach(blob)

        expect { described_class.clone_attachments(original, kopy) }.not_to raise_error
        expect(kopy.reload.piece_justificative_file.attachments.count).to eq(1)
      end
    end
  end
end
