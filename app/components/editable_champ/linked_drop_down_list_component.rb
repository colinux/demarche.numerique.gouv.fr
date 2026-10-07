# frozen_string_literal: true

class EditableChamp::LinkedDropDownListComponent < EditableChamp::EditableChampBaseComponent
  def dsfr_champ_container
    :div
  end

  def render?
    @champ.drop_down_options.any?
  end
end
