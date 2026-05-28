# frozen_string_literal: true

describe ProcedureExportService::XlsxStreamer do
  let(:io) { Tempfile.new(['xlsx_streamer_spec', '.xlsx'], binmode: true) }

  after { io.close!; io.unlink rescue nil }

  def read_sheets
    io.rewind
    xlsx = SimpleXlsxReader.open(io.path)
    xlsx.sheets.each { |s| s.rows.slurp }
    xlsx
  end

  describe 'with a single sheet' do
    subject(:streamer) { described_class.new(io) }

    it 'writes headers and a row of values' do
      streamer.open do |writer|
        writer.write_sheet('Test', headers: ['A', 'B', 'C']) do |sheet|
          sheet.add_row(['hello', 42, nil])
        end
      end

      sheet = read_sheets.sheets.first
      expect(sheet.name).to eq('Test')
      expect(sheet.headers).to eq(['A', 'B', 'C'])
      expect(sheet.data).to eq([['hello', 42, nil]])
    end

    it 'coerces nil to empty string, symbol to string' do
      streamer.open do |writer|
        writer.write_sheet('S', headers: ['x']) do |sheet|
          sheet.add_row([nil])
          sheet.add_row([:foo])
        end
      end

      sheet = read_sheets.sheets.first
      expect(sheet.data).to eq([[nil], ['foo']])
    end
  end

  describe 'formula-like values' do
    subject(:streamer) { described_class.new(io) }

    it 'writes them verbatim as inert text (xlsx string cells are never evaluated)' do
      streamer.open do |writer|
        writer.write_sheet('S', headers: ['x']) do |sheet|
          sheet.add_row(['=1+1'])
          sheet.add_row(['+formula'])
          sheet.add_row(['-cmd'])
          sheet.add_row(['@dde'])
          sheet.add_row(["\tfoo"])
          sheet.add_row(["\rbar"])
          sheet.add_row(['safe'])
        end
      end

      sheet = read_sheets.sheets.first
      values = sheet.data.flatten
      # No leading "'" escape (unlike CSV): the values are stored as-is, matching
      # the previous caxlsx export. Note: XML normalizes \r to \n on serialization
      # (XML 1.0 spec), so SimpleXlsxReader gives back "\nbar" for the \r case.
      expect(values).to eq(['=1+1', '+formula', '-cmd', '@dde', "\tfoo", "\nbar", 'safe'])
    end
  end

  describe 'with multiple sheets' do
    subject(:streamer) { described_class.new(io) }

    it 'writes them sequentially in order' do
      streamer.open do |writer|
        writer.write_sheet('First', headers: ['a']) { |s| s.add_row([1]) }
        writer.write_sheet('Second', headers: ['b']) { |s| s.add_row([2]) }
      end

      expect(read_sheets.sheets.map(&:name)).to eq(['First', 'Second'])
    end
  end

  describe 'sheet name sanitization' do
    subject(:streamer) { described_class.new(io) }

    it 'replaces forbidden chars and truncates to 30 ASCII bytes' do
      raw = 'Élève / Dossier *[] très long ' * 3
      streamer.open do |writer|
        writer.write_sheet(raw, headers: ['x']) { |s| s.add_row(['v']) }
      end

      name = read_sheets.sheets.first.name
      expect(name.bytesize).to be <= 30
      expect(name).not_to match(%r{[/\\*?\[\]]})
      expect(name).to eq(I18n.transliterate(raw, locale: :en).delete('/\*?[]').truncate(30, omission: ''))
    end
  end

  describe 'styling and value types' do
    subject(:streamer) { described_class.new(io) }

    def read_zip_entry(name)
      io.rewind
      Zip::File.open(io.path) { |zip| zip.read(name) }
    end

    before do
      streamer.open do |writer|
        writer.write_sheet('Test', headers: ['Header A', 'Bool']) do |sheet|
          sheet.add_row(['text', true])
          sheet.add_row(['text2', false])
        end
      end
    end

    it 'writes a Ruby boolean as a native boolean cell (t="b")' do
      expect(read_sheets.sheets.first.data).to eq([['text', true], ['text2', false]])
    end

    it 'styles each header cell with a black fill and a white font' do
      styles = read_zip_entry('xl/styles.xml')
      expect(styles).to include('<fgColor rgb="FF000000"/>')
      expect(styles).to include('rgb="FFFFFFFF"')

      # Numbers honors cell-level styles, not row-level ones, so each header
      # cell must carry the style index directly.
      sheet_xml = read_zip_entry('xl/worksheets/sheet1.xml')
      expect(sheet_xml).to match(/<c r="A1" s="3"/)
      expect(sheet_xml).to match(/<c r="B1" s="3"/)
    end

    it 'declares the datetime format with unescaped code so Numbers recognizes it' do
      styles = read_zip_entry('xl/styles.xml')
      expect(styles).to include('formatCode="yyyy-mm-dd h:mm AM/PM"')
    end

    it 'sets column widths' do
      sheet_xml = read_zip_entry('xl/worksheets/sheet1.xml')
      expect(sheet_xml).to match(/<col [^>]*width="[^"]+"[^>]*customWidth="1"/)
    end
  end
end
