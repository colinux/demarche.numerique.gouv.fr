# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260129destroyOrphanEtablissementsTask do
    let!(:orphan_etablissement) { create(:etablissement, dossier: nil) }
    let!(:etablissement_with_dossier) { create(:etablissement, dossier: create(:dossier)) }
    let!(:etablissement_with_champ) do
      procedure = create(:procedure, public_type_de_champs: [{ type: :siret }])
      dossier = create(:dossier, procedure:)
      etablissement = create(:etablissement, dossier: nil)
      dossier.champ_data.first.update!(etablissement:)
      etablissement
    end

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      it "ends with the range holding the last etablissement" do
        expect(collection.last..(collection.last + described_class::RANGE_SIZE - 1)).to cover(etablissement_with_champ.id)
      end
    end

    describe "#process" do
      subject(:process) { described_class.new.process(orphan_etablissement.id) }

      it "destroys only the orphan etablissements of the range" do
        process

        expect(Etablissement.where(id: [orphan_etablissement, etablissement_with_dossier, etablissement_with_champ]))
          .to contain_exactly(etablissement_with_dossier, etablissement_with_champ)
      end
    end
  end
end
