# frozen_string_literal: true

module DossierDemandeurSiretConcern
  extend ActiveSupport::Concern

  def demandeur_siret_awaiting_fix? = demandeur_siret&.awaiting_fix? || false

  def siret = etablissement&.siret || demandeur_siret&.siret

  def siren = etablissement ? etablissement.siren : demandeur_siret&.siret&.first(9)
end
