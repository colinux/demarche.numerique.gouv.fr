# frozen_string_literal: true

module AttestationDepotHelper
  def attestation_depot_requester_identity(dossier)
    if dossier.etablissement.present?
      raison_sociale_or_name(dossier.etablissement)
    elsif dossier.individual.present?
      [dossier.individual.prenom, dossier.individual.nom.upcase].join(' ')
    elsif dossier.siret.present?
      t('views.shared.dossiers.demande.unverified_siret', siret: pretty_siret(dossier.siret))
    end
  end

  def attestation_depot_dossier_state(dossier)
    raise "Dossiers in 'brouillon' state are not supported" if dossier.brouillon?
    # i18n-tasks-use t('users.dossiers.attestation_depot.states.en_construction')
    # i18n-tasks-use t('users.dossiers.attestation_depot.states.en_instruction')
    # i18n-tasks-use t('users.dossiers.attestation_depot.states.accepte')
    # i18n-tasks-use t('users.dossiers.attestation_depot.states.refuse')
    # i18n-tasks-use t('users.dossiers.attestation_depot.states.sans_suite')
    t("users.dossiers.attestation_depot.states.#{dossier.state}")
  end
end
