# frozen_string_literal: true

# Streams a procedure's dossiers into an xlsx file with bounded memory: the
# Dossiers sheet is written row by row while the secondary sheets
# (Etablissements, Avis, Repetitions) are buffered as primitive values and
# flushed once Dossiers is closed (xlsxtream cannot interleave sheets).
#
# Kept separate from ProcedureExportService so the multi-format service stays a
# thin dispatcher; the same streaming shape can later back a CSV export.
class ProcedureExportService::XlsxExport
  def initialize(procedure:, dossiers:, export_template:)
    @procedure = procedure
    @dossiers = dossiers
    @export_template = export_template
  end

  # Résout une cellule `[libellé, valeur, type]` (le type n'est présent que via
  # export_template). Reproduit le typage de SpreadsheetArchitect : un booléen
  # ne devient une cellule native (t="b") que si la colonne est explicitement
  # typée `:boolean` ; sinon il est stringifié — comme l'export caxlsx précédent,
  # où `get_type` ne typait jamais les booléens auto-détectés.
  def self.cell_value(instance, value, type)
    value = instance.send(value) if value.is_a?(Symbol)

    if (value == true || value == false) && type != :boolean
      value.to_s
    else
      value
    end
  end

  def write_to(io)
    buffers = SecondarySheetBuffers.new(procedure: @procedure)

    ProcedureExportService::XlsxStreamer.new(io).open do |writer|
      stream_dossiers_sheet(writer, buffers)
      flush_etablissements_sheet(writer, buffers)
      flush_avis_sheet(writer, buffers)
      flush_repetition_sheets(writer, buffers)
    end
  end

  private

  def stream_dossiers_sheet(writer, buffers)
    writer.write_sheet('Dossiers', headers: dossiers_headers) do |sheet|
      DossierPreloader.new(@dossiers.ordered_for_export)
        .in_batches(includes: DossierPreloader::SHEET_EXPORT_INCLUDES) do |batch|
        batch.each do |dossier|
          row = dossier.spreadsheet_columns_xlsx(types_de_champ:, export_template: @export_template)
          sheet.add_row(row.map { |(_libelle, value, type)| self.class.cell_value(dossier, value, type) })

          buffers.collect_for_dossier(dossier, @export_template)
        end
      end
    end
  end

  def flush_etablissements_sheet(writer, buffers)
    writer.write_sheet('Etablissements', headers: buffers.etablissements_headers) do |sheet|
      buffers.etablissements_rows.each { |values| sheet.add_row(values) }
    end
  end

  def flush_avis_sheet(writer, buffers)
    writer.write_sheet('Avis', headers: buffers.avis_headers) do |sheet|
      buffers.avis_rows.each { |values| sheet.add_row(values) }
    end
  end

  def flush_repetition_sheets(writer, buffers)
    buffers.repetition_sheets.each do |(libelle, headers, rows)|
      writer.write_sheet(libelle, headers:) do |sheet|
        rows.each { |values| sheet.add_row(values) }
      end
    end
  end

  def dossiers_headers
    return @dossiers_headers if defined?(@dossiers_headers)

    # Précalcul depuis une instance "sentinelle" pour garantir la cohérence
    # libellé ↔ valeur. Si pas de dossier, on ouvre quand même une sheet vide.
    sample = @dossiers.first
    @dossiers_headers = if sample.present?
      DossierPreloader.load_one(sample)
        .spreadsheet_columns_xlsx(types_de_champ:, export_template: @export_template)
        .map(&:first)
    else
      []
    end
  end

  def types_de_champ
    @types_de_champ ||= @procedure.types_de_champ_for_procedure_export.to_a
  end

  # Accumulates rows for the Etablissements, Avis and Repetition sheets while we
  # stream the main Dossiers sheet.
  #
  # Values from `spreadsheet_columns` may be raw values or Symbols (method names
  # to call on the source instance, mimicking SpreadsheetArchitect behavior).
  # We resolve them at collection time so the buffer only holds primitive values.
  class SecondarySheetBuffers
    ETABLISSEMENT_HEADERS = Etablissement.new.spreadsheet_columns.map(&:first).freeze
    AVIS_HEADERS = Avis.new.spreadsheet_columns.map(&:first).freeze

    def initialize(procedure:)
      @procedure = procedure
      @etablissements_buffer = []
      @avis_buffer = []
      @repetition_buffers = {} # stable_id => { libelle:, headers:, rows: [] }
    end

    def collect_for_dossier(dossier, export_template)
      collect_etablissements(dossier)
      collect_avis(dossier)
      collect_repetitions(dossier, export_template)
    end

    def etablissements_headers = ETABLISSEMENT_HEADERS
    def etablissements_rows = @etablissements_buffer
    def avis_headers = AVIS_HEADERS
    def avis_rows = @avis_buffer

    def repetition_sheets
      @repetition_buffers.values.filter_map do |entry|
        next if entry[:rows].empty?
        [entry[:libelle], entry[:headers], entry[:rows]]
      end
    end

    private

    def collect_etablissements(dossier)
      dossier.filled_champs.filter(&:siret?).filter_map(&:etablissement).each do |etablissement|
        @etablissements_buffer << resolve_values(etablissement, etablissement.spreadsheet_columns)
      end

      if dossier.etablissement
        @etablissements_buffer << resolve_values(dossier.etablissement, dossier.etablissement.spreadsheet_columns)
      end
    end

    def collect_avis(dossier)
      dossier.avis.each do |avis|
        @avis_buffer << resolve_values(avis, avis.spreadsheet_columns)
      end
    end

    def collect_repetitions(dossier, export_template)
      repetition_tdcs.each do |tdc|
        rows = dossier.repetition_rows_for_export(tdc)
        next if rows.empty?

        children_tdcs = repetition_children_tdcs[tdc.stable_id]
        entry = @repetition_buffers[tdc.stable_id] ||= {
          libelle: tdc.libelle_for_export,
          headers: nil,
          rows: [],
        }

        rows.each do |row|
          columns = row.spreadsheet_columns(children_tdcs, export_template:, format: :xlsx)
          entry[:headers] ||= columns.map(&:first)
          entry[:rows] << resolve_values(row, columns)
        end
      end
    end

    def repetition_tdcs
      @repetition_tdcs ||= @procedure.all_revisions_types_de_champ.repetition.to_a
    end

    def repetition_children_tdcs
      @repetition_children_tdcs ||= repetition_tdcs.to_h do |tdc|
        [tdc.stable_id, @procedure.all_revisions_types_de_champ(parent: tdc).to_a]
      end
    end

    def resolve_values(instance, columns)
      columns.map do |(_libelle, value, type)|
        ProcedureExportService::XlsxExport.cell_value(instance, value, type)
      end
    end
  end
end
