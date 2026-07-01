# frozen_string_literal: true

class AddJSONColumnsToMailTemplates < ActiveRecord::Migration[8.0]
  TABLES = [
    :initiated_mails,
    :received_mails,
    :closed_mails,
    :refused_mails,
    :without_continuation_mails,
    :re_instructed_mails,
  ]

  def change
    TABLES.each do |table|
      add_column table, :json_body, :jsonb
      add_column table, :json_subject, :jsonb
    end
  end
end
