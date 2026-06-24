# frozen_string_literal: true

class Champs::DossierLinkChamp < ChampData
  validates_with DossierLinkValidator, if: -> { should_validate_in_current_context? && value.present? }

  # The (still existing) procedures the field is restricted to, in the admin-configured order.
  def linkable_procedures
    @linkable_procedures ||= begin
      ids = type_de_champ.dossier_link_procedure_ids
      Procedure.where(id: ids).index_by(&:id).values_at(*ids).compact
    end
  end

  # The user's submitted dossiers on those procedures, grouped by procedure (newest first).
  def linkable_dossiers_by_procedure
    @linkable_dossiers_by_procedure ||= linkable_procedures.index_with do |procedure|
      procedure.dossiers
        .visible_by_user_or_administration
        .where(user_id: dossier.user_id, state: Dossier::SOUMIS)
        .where.not(id: dossier_id)
        .order(depose_at: :desc)
        .to_a
    end
  end

  # Offer a select/combobox (rather than free input) only when the field is limited
  # to procedures AND the user actually has at least one dossier to pick. Otherwise we
  # keep free input so the user can still type a number (e.g. a since-deleted dossier).
  def selectable?
    type_de_champ.procedures_limit? && linkable_dossiers_by_procedure.values.any?(&:present?)
  end
end
