# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260924normalizeServiceLinksTask do
    let(:service) { create(:service) }

    # raw sql: an attribute write would normalize the links
    def store(**links)
      Service.where(id: service.id).update_all([links.keys.map { "#{it} = ?" }.join(', '), *links.values])
      service.reload
    end

    describe "#collection" do
      subject(:collection) { described_class.new.collection }

      it "includes a service with a link" do
        store(faq_link: nil, contact_link: 'www.mairie.fr/contact')
        expect(collection).to include(service)
      end

      it "leaves out a service without link" do
        store(faq_link: nil, contact_link: nil)
        expect(collection).not_to include(service)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(service) }

      it "normalizes the links" do
        store(faq_link: ' https://www.mairie.fr/faq ', contact_link: 'www.mairie.fr/contact')
        process

        expect(service.reload).to have_attributes(faq_link: 'https://www.mairie.fr/faq', contact_link: 'https://www.mairie.fr/contact')
      end

      it "leaves a link the normalization does not make valid" do
        store(faq_link: ' faq de la mairie ', contact_link: ' mailto:contact@mairie.fr ')
        process

        expect(service.reload).to have_attributes(faq_link: ' faq de la mairie ', contact_link: ' mailto:contact@mairie.fr ')
      end
    end
  end
end
