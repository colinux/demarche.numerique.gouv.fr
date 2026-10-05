# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20261005RelinkFranceConnectInvitesTask do
    describe "#process" do
      let(:email) { "invite-fc@example.com" }
      let(:invite) { create(:invite, dossier: dossiers.en_construction, email:, user: nil) }

      subject(:process) { described_class.process(Invite.where(id: invite.id)) }

      context "when a confirmed user has the invite email" do
        let!(:user) { create(:user, email:) }

        it "links the invite to the user" do
          expect { process }.to change { invite.reload.user }.from(nil).to(user)
        end
      end

      context "when the user with the invite email is not confirmed" do
        before { create(:user, email:, confirmed_at: nil) }

        it "leaves the invite unlinked" do
          expect { process }.not_to change { invite.reload.user }
        end
      end
    end
  end
end
