# frozen_string_literal: true

class ProcedureExportService::XlsxStreamer
  def initialize(io)
    @io = io
  end

  def open
    Xlsxtream::Workbook.open(@io) do |workbook|
      @workbook = workbook
      yield(self)
    end
  end

  def write_sheet(name, headers:)
    sanitized = ProcedureExportService.sanitize_sheet_name(name)
    @workbook.write_worksheet(sanitized, columns: column_widths(headers)) do |sheet|
      sheet.add_styled_row(headers, style: Xlsxtream::HEADER_STYLE)
      # On yielde la feuille xlsxtream brute : xlsxtream coerce lui-même nil → cellule
      # vide et Symbol → texte (cf. Row#to_xml). Les valeurs sont par ailleurs déjà
      # résolues et typées en amont par XlsxExport.cell_value (parité SpreadsheetArchitect,
      # ex. booléen non typé → texte). Pas d'échappement de formule : une cellule chaîne
      # xlsx n'est jamais évaluée (seul un <f> l'est).
      yield(sheet)
    end
  end

  private

  # Le streaming interdit l'autofit : on dimensionne d'après le libellé d'en-tête,
  # avec un plancher assez large pour que les colonnes de valeurs (texte, dates
  # « yyyy-mm-dd h:mm AM/PM », emails…) restent lisibles, et un plafond pour
  # éviter qu'un libellé à rallonge n'étale la colonne.
  def column_widths(headers)
    headers.map { { width_chars: it.to_s.length.clamp(22, 60) } }
  end
end
