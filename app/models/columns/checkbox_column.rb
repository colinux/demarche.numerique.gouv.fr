# frozen_string_literal: true

class Columns::CheckboxColumn < Columns::ChampColumn
  # A checkbox has two states, where a yes/no has three: left alone it displays
  # unchecked, so no answer reads false rather than nil.
  def value(champ) = super || false
end
