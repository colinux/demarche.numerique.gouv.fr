# frozen_string_literal: true

class AddInactivityClockIndexToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users,
      "COALESCE(current_sign_in_at, created_at)",
      name: "index_users_on_inactivity_clock",
      algorithm: :concurrently
  end
end
