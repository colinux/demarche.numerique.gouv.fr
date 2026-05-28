# frozen_string_literal: true

# Portable patches for xlsxtream 3.1.0 (streaming xlsx exports, see
# ProcedureExportService::XlsxStreamer). xlsxtream hardcodes its stylesheet and
# exposes no per-cell styling API, so we:
#   - add a black-fill / white-bold header style, applied to each header *cell*
#     (Numbers ignores row-level styles), via Worksheet#add_styled_row
#   - replace xlsxtream's escaped custom date formats with the ones caxlsx used
#     (built-in short date + "yyyy-mm-dd h:mm AM/PM"), which Numbers reads as
#     dates and which match the previous (caxlsx) export byte-for-byte
#
# All confined here (auto-required by config/initializers/core_ext.rb, like the
# other gem extensions in lib/core_ext); remove if xlsxtream ever exposes these
# natively. https://github.com/felixbuenemann/xlsxtream
if Xlsxtream::VERSION != "3.1.0"
  raise "xlsxtream #{Xlsxtream::VERSION}: review patches in #{__FILE__} " \
        "(styles.xml / Row#to_xml internals may have changed)"
end

module Xlsxtream
  # cellXfs index of the header style defined in StyledWorkbook#write_styles below.
  HEADER_STYLE = 3

  module StyledWorkbook
    private

    # Full override of upstream's hardcoded stylesheet. Differences:
    #   - dates (cellXf 1) use the built-in short-date format (numFmtId 14)
    #   - datetimes (cellXf 2) use "yyyy-mm-dd h:mm AM/PM"
    #   - header (cellXf 3) uses a white bold font on a black fill
    # The font is hardcoded to upstream's default (we never pass the :font option).
    def write_styles
      @writer.add_file "xl/styles.xml"
      @writer << XML.header
      @writer << XML.strip(<<-XML)
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <numFmts count="1">
            <numFmt numFmtId="165" formatCode="yyyy-mm-dd h:mm AM/PM"/>
          </numFmts>
          <fonts count="2">
            <font>
              <sz val="12"/>
              <name val="Calibri"/>
              <family val="2"/>
            </font>
            <font>
              <b/>
              <sz val="12"/>
              <color rgb="FFFFFFFF"/>
              <name val="Calibri"/>
              <family val="2"/>
            </font>
          </fonts>
          <fills count="3">
            <fill>
              <patternFill patternType="none"/>
            </fill>
            <fill>
              <patternFill patternType="gray125"/>
            </fill>
            <fill>
              <patternFill patternType="solid">
                <fgColor rgb="FF000000"/>
                <bgColor indexed="64"/>
              </patternFill>
            </fill>
          </fills>
          <borders count="1">
            <border/>
          </borders>
          <cellStyleXfs count="1">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
          </cellStyleXfs>
          <cellXfs count="4">
            <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
            <xf numFmtId="14" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
            <xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
            <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
          </cellXfs>
          <cellStyles count="1">
            <cellStyle name="Normal" xfId="0" builtinId="0"/>
          </cellStyles>
          <dxfs count="0"/>
          <tableStyles count="0" defaultTableStyle="TableStyleMedium9" defaultPivotStyle="PivotStyleLight16"/>
        </styleSheet>
      XML
    end
  end
  Workbook.prepend(StyledWorkbook)

  # Applies a style to every cell of a row. Numbers ignores row-level styling
  # (<row s=.. customFormat="1">), so we add an explicit s= on each <c>, like
  # caxlsx does. We call super (keeping upstream's cell-typing untouched) then
  # inject s= into each cell that doesn't already carry one.
  module StyledRow
    def initialize(row, rownum, options = {})
      super
      @row_style = options[:row_style]
    end

    def to_xml
      xml = super
      return xml unless @row_style

      xml.gsub(/<c r="[A-Z]+\d+"(?! s=)/) { |cell| %(#{cell} s="#{@row_style}") }
    end
  end
  Row.prepend(StyledRow)

  # The only entry point to write a row with a row-level style.
  module StyledWorksheet
    def add_styled_row(row, style:)
      @io << Row.new(row, @rownum, @options.merge(row_style: style)).to_xml
      @rownum += 1
    end
  end
  Worksheet.prepend(StyledWorksheet)
end
