# frozen_string_literal: true

class EditableChamp::DossierLinkComponent < EditableChamp::EditableChampBaseComponent
  COMBOBOX_THRESHOLD = 20

  def dsfr_input_classname
    limited? ? 'fr-select' : 'fr-input'
  end

  def limited?
    @champ.type_de_champ.procedures_limit? && allowed_procedures.any?
  end

  def render_combobox?
    total_dossiers >= COMBOBOX_THRESHOLD
  end

  def grouped_select_options
    grouped_dossiers.map do |procedure, dossiers|
      options = if dossiers.empty?
        [[t('.no_dossier_in_procedure'), '', { disabled: true }]]
      else
        dossiers.map { |dossier| [option_label(dossier), dossier.id.to_s] }
      end

      [t('.procedure_group', libelle: procedure.libelle), options]
    end
  end

  def combobox_react_props
    {
      id: @champ.focusable_input_id,
      name: @form.field_name(:value),
      sections: combobox_sections,
      selected_key: @champ.value.presence,
      placeholder: t('.select_placeholder'),
      is_required: @champ.required?,
      'aria-describedby': select_aria_describedby,
    }.compact
  end

  def select_class_names
    class_names('width-100': contains_long_option?, 'fr-select': true)
  end

  def select_aria_describedby
    describedby = []
    describedby << @champ.describedby_id if @champ.description.present?
    describedby << @champ.error_id(:value) if errors_on_attribute?
    describedby.presence&.join(' ')
  end

  private

  def combobox_sections
    grouped_dossiers.map do |procedure, dossiers|
      {
        label: t('.procedure_section', libelle: procedure.libelle),
        items: dossiers.map { |dossier| { label: option_label(dossier), value: dossier.id.to_s } },
      }
    end
  end

  def allowed_procedures
    @allowed_procedures ||= begin
      ids = @champ.type_de_champ.dossier_link_procedure_ids
      Procedure.where(id: ids).index_by(&:id).values_at(*ids).compact
    end
  end

  def grouped_dossiers
    @grouped_dossiers ||= allowed_procedures.index_with do |procedure|
      procedure.dossiers
        .visible_by_user_or_administration
        .where(user_id: @champ.dossier.user_id, state: Dossier::SOUMIS)
        .where.not(id: @champ.dossier_id)
        .order(depose_at: :desc)
    end
  end

  def total_dossiers
    grouped_dossiers.sum { |_procedure, dossiers| dossiers.size }
  end

  def contains_long_option?
    grouped_dossiers.any? { |procedure, _dossiers| procedure.libelle.size > 100 }
  end

  def option_label(dossier)
    t('.option', id: dossier.id, date: l(dossier.depose_at.to_date))
  end
end
