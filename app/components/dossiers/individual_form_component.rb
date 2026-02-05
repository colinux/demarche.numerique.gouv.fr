# frozen_string_literal: true

class Dossiers::IndividualFormComponent < ApplicationComponent
  delegate :for_tiers?, to: :@dossier

  def initialize(dossier:)
    @dossier = dossier
  end

  def email_notifications?(individual)
    individual.object.notification_method == Individual.notification_methods[:email]
  end

  def identity_locked?
    !for_tiers? && @dossier.france_connected_with_one_identity?
  end

  def mandataire_identity_locked?
    @dossier.france_connected_with_one_identity?
  end
end
