# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260924normalizeProcedureLinksTask do
    let(:procedure) { procedures.brouillon }

    # raw sql: an attribute write would normalize the links
    def store(**links)
      Procedure.where(id: procedure.id).update_all([links.keys.map { "#{it} = ?" }.join(', '), *links.values])
      procedure.reload
    end

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      it "includes a procedure with a link, even discarded" do
        store(web_hook_url: 'hooks.mairie.fr/in', hidden_at: Time.zone.now)
        expect(collection).to include(procedure)
      end

      it "leaves out a procedure without link" do
        store(lien_notice: nil, lien_dpo: nil, web_hook_url: nil)
        expect(collection).not_to include(procedure)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(procedure) }

      it "normalizes the links" do
        store(lien_notice: ' https://www.mairie.fr/notice ', lien_dpo: ' mailto:DPO@mairie.fr ', web_hook_url: 'hooks.mairie.fr/in')
        process

        expect(procedure.reload).to have_attributes(
          lien_notice: 'https://www.mairie.fr/notice',
          lien_dpo: 'dpo@mairie.fr',
          web_hook_url: 'https://hooks.mairie.fr/in'
        )
      end

      it "completes a link without scheme" do
        store(lien_dpo: 'www.mairie.fr/dpo')
        process

        expect(procedure.reload.lien_dpo).to eq('https://www.mairie.fr/dpo')
      end

      it "leaves a link the normalization does not make valid" do
        store(lien_notice: ' notice de la mairie ', lien_dpo: ' dpo@mairie.fr ; rgpd@mairie.fr ')
        process

        expect(procedure.reload).to have_attributes(lien_notice: ' notice de la mairie ', lien_dpo: ' dpo@mairie.fr ; rgpd@mairie.fr ')
      end
    end
  end
end
