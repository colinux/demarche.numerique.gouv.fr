# frozen_string_literal: true

class EditableChamp::PaysComponent < EditableChamp::EditableChampBaseComponent
  include ApplicationHelper

  def dsfr_input_classname
    'fr-select'
  end

  private

  def options
    options = APIGeoService.country_options
    # For legacy fields, selected value is non standard country name. Add it to the list.
    if (@champ.selected&.size || 0) > 2
      options.unshift([@champ.selected, @champ.selected])
    end
    options
  end
end
