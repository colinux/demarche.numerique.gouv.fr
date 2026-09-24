# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260922backfillAnnuaireEducationValueJSONTask do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :annuaire_education }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.champ_data.first }
    let(:data) { { 'nom_etablissement' => 'École historique', 'nom_commune' => 'Ici' } }

    # What #collection yields: the first id of a range covering the champ.
    def run! = described_class.new.process(champ.id)

    describe "#process" do
      before { champ.update_columns(data:, value_json: nil) }

      it "persists the value_json computed from data" do
        expect { run! }
          .to change { champ.reload.read_attribute(:value_json) }
          .from(nil).to(champ.send(:extract_value_json, data:))
      end

      it "is idempotent" do
        run!

        expect { run! }.not_to(change { champ.reload.read_attribute(:value_json) })
      end

      it "leaves alone the champs already holding a value_json" do
        champ.update_columns(value_json: { 'nom_etablissement' => 'École déjà migrée' })

        expect { run! }.not_to(change { champ.reload.read_attribute(:value_json) })
      end
    end

    describe "#collection" do
      subject(:ranges) { described_class.new.collection }

      it "covers every champ, whatever the gaps in the id sequence" do
        expect(ranges.any? { (_1...(_1 + described_class::RANGE_SIZE)).cover?(champ.id) }).to be(true)
      end

      it "starts on the first champ and runs past the last" do
        expect(ranges.first).to eq(ChampData.minimum(:id))
        expect(ranges.last + described_class::RANGE_SIZE).to be > ChampData.maximum(:id)
      end
    end
  end
end
