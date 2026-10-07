# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261020ConvertDegradedEtablissementsTask do
    let(:dossier) { dossiers.entreprise_en_instruction }
    let(:stub) { dossier.etablissement }

    before { stub.update_columns(adresse: nil) }

    describe "#collection" do
      it "takes the stubs of dossiers" do
        expect(described_class.collection).to include(stub)
      end

      it "leaves out a complete etablissement" do
        expect(described_class.collection).not_to include(dossiers.avec_siret.etablissement)
      end

      it "leaves out a stub without SIRET" do
        stub.update_columns(siret: nil)

        expect(described_class.collection).not_to include(stub)
      end

      it "leaves out a stub whose dossier is gone" do
        stub.update_columns(dossier_id: 0)

        expect(described_class.collection).not_to include(stub)
      end

      it "leaves out a stub tied to a champ" do
        champ = dossier.champ_data.first
        stub.update_columns(dossier_id: nil)
        champ.update_columns(etablissement_id: stub.id)

        expect(described_class.collection).not_to include(stub)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(stub) }

      it "turns the stub into a degraded demandeur SIRET" do
        siret = stub.siret

        process

        expect(Etablissement.where(id: stub.id)).to be_empty
        expect(dossier.reload.demandeur_siret).to have_attributes(siret:, external_state: 'degraded')
      end

      it "does not make the dossier look modified" do
        expect { process }.not_to change { dossier.reload.updated_at }
      end

      it "does nothing twice" do
        process
        described_class.process(stub)

        expect(DemandeurSiret.where(dossier:).count).to eq(1)
      end
    end
  end
end
