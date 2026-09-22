# frozen_string_literal: true

class ExpertsProcedure < ApplicationRecord
  belongs_to :expert
  belongs_to :procedure

  has_many :avis, dependent: :destroy

  scope :not_revoked, -> { where(revoked_at: nil) }

  def revoked?
    revoked_at.present?
  end
end
