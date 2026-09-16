# frozen_string_literal: true

describe TiptapContentScrubber do
  def scrub(html)
    ActionController::Base.helpers.sanitize(html, scrubber: described_class.new)
  end

  it 'keeps everything TiptapService can emit' do
    json = {
      type: 'doc',
      content: [
        {
          type: 'header',
          content: [
            { type: 'headerColumn', attrs: { textAlign: 'left' }, content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Colonne' }] }] },
          ],
        },
        { type: 'title', attrs: { textAlign: 'center' }, content: [{ type: 'text', text: 'Titre' }] },
        { type: 'heading', attrs: { level: 2 }, content: [{ type: 'text', text: 'Sous-titre' }] },
        {
          type: 'paragraph',
          content: [
            { type: 'text', text: 'gras', marks: [{ type: 'bold' }] },
            { type: 'text', text: ' italique', marks: [{ type: 'italic' }] },
            { type: 'text', text: ' souligné', marks: [{ type: 'underline' }] },
            { type: 'text', text: ' surligné', marks: [{ type: 'highlight' }] },
            { type: 'hardBreak' },
            { type: 'text', text: 'suite' },
          ],
        },
        { type: 'bulletList', content: [{ type: 'listItem', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'puce' }] }] }] },
        { type: 'paragraph', content: [{ type: 'text', text: 'Bloc : ' }, { type: 'mention', attrs: { id: 'bloc', label: 'bloc' } }] },
        { type: 'pageBreak' },
        { type: 'paragraph', content: [{ type: 'text', text: 'Fin.' }] },
      ],
    }
    champ = double(libelle: 'Nom', to_s: 'Dupont', blank?: false)
    blank_champ = double(libelle: 'Prénom', to_s: '', blank?: true)
    substitutions = { 'bloc' => ChampPresentations::RepetitionPresentation.new('Personnes', [double(flat_children: [champ, blank_champ])]) }

    html = TiptapService.new(hard_break: '<br><br>').to_html(json, substitutions)
    scrubbed = Nokogiri::HTML5.fragment(scrub(html))

    expect(scrubbed.css('header, h1, h2, ul li, ol.tdc-repetition, dl dt.invisible, dd, br').size).to be >= 8
    expect(scrubbed.css('strong, em, u, mark').map(&:text)).to eq(['gras', ' italique', ' souligné', ' surligné'])
    expect(scrubbed.at_css('h1')['style']).to eq('text-align: center')
    expect(scrubbed.at_css('div.page-break')).to be_present
    expect(scrubbed.at_css('h2.body-start')).to be_present
  end

  it 'strips hostile markup while keeping legitimate text' do
    scrubbed = scrub(<<~HTML)
      <script>alert("xss")</script>
      <blockquote>citation</blockquote>
      <img src="tracker.png" alt="pixel">
      <a href="https://evil.example" target="_blank">lien</a>
      <iframe src="https://evil.example"></iframe>
      <mark>surligné</mark>
    HTML

    expect(scrubbed).not_to include('script', 'alert', 'blockquote', 'img', '<a', 'iframe', 'evil.example')
    expect(scrubbed).to include('citation', 'lien', '<mark>surligné</mark>')
  end

  it 'filters style declarations down to text-align' do
    scrubbed = scrub('<p style="color: red; text-align: center">texte</p><p style="color: red">rouge</p>')

    expect(scrubbed).to eq('<p style="text-align: center">texte</p><p>rouge</p>')
  end

  it 'filters classes down to the TipTap vocabulary' do
    scrubbed = scrub('<div class="page-break fr-hidden"></div><p class="hack">texte</p>')

    expect(scrubbed).to eq('<div class="page-break"></div><p>texte</p>')
  end
end
