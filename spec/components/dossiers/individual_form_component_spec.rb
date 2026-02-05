# frozen_string_literal: true

require "rails_helper"

RSpec.describe Dossiers::IndividualFormComponent, type: :component do
  let(:procedure) { create(:procedure, :published, :for_individual, no_gender: false) }
  let(:dossier) { create(:dossier, :with_individual, procedure:, user:) }

  subject { render_inline(described_class.new(dossier:)) }

  context "when user is connected via France Connect" do
    let(:user) { create(:user, :with_fci) }

    context "for self" do
      it "identity fields are disabled" do
        subject
        expect(page).to have_field("Prénom", disabled: true)
        expect(page).to have_field("Nom", disabled: true)
        expect(page).to have_css("input[name='dossier[individual_attributes][gender]'][disabled]")
      end
    end

    context "for tiers" do
      let(:dossier) { create(:dossier, :for_tiers_without_notification, procedure:, user:) }

      it "mandataire fields are disabled" do
        subject
        within(".mandataire-infos") do
          expect(page).to have_field("Prénom", disabled: true)
          expect(page).to have_field("Nom", disabled: true)
        end
      end

      it "beneficiary identity fields are editable" do
        subject
        within(".individual-infos") do
          expect(page).to have_field("Prénom", disabled: false)
          expect(page).to have_field("Nom", disabled: false)
        end
      end
    end
  end

  context "when user is not connected via France Connect" do
    let(:user) { create(:user) }

    it "identity fields are editable" do
      subject
      expect(page).to have_field("Prénom", disabled: false)
      expect(page).to have_field("Nom", disabled: false)
    end
  end
end
