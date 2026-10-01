# frozen_string_literal: true

class Banner < ApplicationRecord
  TARGETS = {
    global: "global",
    instructeurs_only: "instructeurs_only",
    usagers_only: "usagers_only",
    login_page: "login_page",
    manager_login: "manager_login",
  }.freeze

  TARGET_LABELS = {
    "global" => "Bannière globale",
    "instructeurs_only" => "Bannière instructeurs",
    "usagers_only" => "Bannière usagers",
    "login_page" => "Page de connexion",
    "manager_login" => "Connexion manager",
  }.freeze

  TARGET_DESCRIPTIONS = {
    "global" => "Visible par tous les utilisateurs sur toutes les pages",
    "instructeurs_only" => "Visible uniquement par les instructeurs connectés",
    "usagers_only" => "Visible par tous les profils non-instructeurs (usagers, administrateurs, experts, gestionnaires)",
    "login_page" => "Visible sur les pages de connexion et d'inscription (/users/sign_in, /users/sign_up)",
    "manager_login" => "Visible sur la page de connexion super admin (/super_admins/sign_in)",
  }.freeze

  SANITIZE_TAGS = %w[a strong em b i br u abbr sub sup].freeze

  enum :target, TARGETS

  validates :target, presence: true, uniqueness: true

  def active?
    content.present?
  end

  # Rendered by the layout of the error pages too: without a database
  # (connection lost, not only a failed statement) the page shows no banner.
  def self.cached_for(target)
    Rails.cache.fetch("banner/#{target}", expires_in: 1.minute) do
      find_by(target: target)
    end
  rescue ActiveRecord::ActiveRecordError
    nil
  end

  after_commit :bust_cache

  private

  def bust_cache
    Rails.cache.delete("banner/#{target}")
  end
end
