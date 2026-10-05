# frozen_string_literal: true

module ProfilContextConcern
  extend ActiveSupport::Concern

  ALLOWED_NAV_BAR_PROFILES = [:user, :instructeur, :administrateur, :expert, :gestionnaire].freeze

  def nav_bar_profile
    context = params[:context]&.to_sym
    return context if ALLOWED_NAV_BAR_PROFILES.include?(context)
    fallback_nav_bar_profile.presence || :user
  end
end
