# frozen_string_literal: true

module Maintenance
  class T20261005RelinkFranceConnectInvitesTask < MaintenanceTasks::Task
    # include RunnableOnDeployConcern

    # run_on_first_deploy

    # Accounts created through FranceConnect were confirmed without going
    # through Devise's `after_confirmation`, so the invites sent to their email
    # before they signed up were never linked to them.
    def collection
      Invite.where(user_id: nil).in_batches
    end

    # Confirmed accounts only: an unconfirmed one has not proven it owns the
    # email, and will link its invites when it confirms.
    def process(batch)
      user_ids = User.where(email: batch.pluck(:email)).where.not(confirmed_at: nil).pluck(:email, :id).to_h

      batch.where(email: user_ids.keys).find_each { it.update_column(:user_id, user_ids[it.email]) }
    end
  end
end
