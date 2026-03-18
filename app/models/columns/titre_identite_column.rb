# frozen_string_literal: true

class Columns::TitreIdentiteColumn < Columns::ChampColumn
  private

  def typed_value(champ)
    champ.piece_justificative_file.attached? ? true : false
  end
end
