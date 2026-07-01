# frozen_string_literal: true

RSpec.describe TiptapService do
  let(:json) do
    {
      type: 'doc',
      content: [
        {
          type: 'header',
          content: [
            {
              type: 'headerColumn',
              content: [{ type: 'text', text: 'Left' }],
            },
            {
              type: 'headerColumn',
              content: [{ type: 'text', text: 'Right' }],
            },
          ],
        },
        {
          type: 'title',
          content: [{ type: 'text', text: 'Title' }],
        },
        {
          type: 'title', # remained empty in editor
        },
        {
          type: 'heading',
          attrs: { level: 2, textAlign: 'center' },
          content: [{ type: 'text', text: 'Heading 2' }],
        },
        {
          type: 'heading',
          attrs: { level: 3, textAlign: 'center' },
          content: [{ type: 'text', text: 'Heading 3' }],
        },
        {
          type: 'heading',
          attrs: { level: 3 }, # remained empty in editor
        },
        {
          type: 'paragraph',
          attrs: { textAlign: 'right' },
          content: [{ type: 'text', text: 'First paragraph' }],
        },
        {
          type: 'paragraph',
          content: [
            {
              type: 'text',
              text: 'Bonjour ',
              marks: [{ type: 'italic' }, { type: 'strike' }],
            },
            {
              type: 'mention',
              attrs: { id: 'name', label: 'Nom' },
              marks: [{ type: 'bold' }, { type: 'underline' }],
            },
            {
              type: 'text',
              text: ' ',
            },
            {
              type: 'text',
              text: '!',
              marks: [{ type: 'highlight' }],
            },
          ],
        },
        {
          type: 'paragraph',
          # no content, empty line
        },
        {
          type: 'bulletList',
          content: [
            {
              type: 'listItem',
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Item 1',
                    },
                  ],
                },
              ],
            },
            {
              type: 'listItem',
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Item 2',
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          type: 'orderedList',
          content: [
            {
              type: 'listItem',
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Item 1',
                    },
                  ],
                },
              ],
            },
            {
              type: 'listItem',
              content: [
                {
                  type: 'paragraph',
                  content: [
                    {
                      type: 'text',
                      text: 'Item 2',
                    },
                  ],
                },
              ],
            },
          ],
        },
        {
          type: 'paragraph',
          content: [
            {
              type: 'text',
              text: 'Langages de prédilection:',
            },
            {
              type: 'mention',
              attrs: { id: 'languages', label: 'Langages' },
            },
          ],
        },
        {
          type: 'footer',
          content: [{ type: 'text', text: 'Footer' }],
        },
      ],
    }
  end

  describe '.to_html' do
    let(:substitutions) { { 'name' => 'Paul', 'languages' => ChampPresentations::MultipleDropDownListPresentation.new(['ruby', 'rust']) } }
    let(:html) do
      [
        '<header><div>Left</div><div>Right</div></header>',
        '<h1>Title</h1>',
        '<h2 class="body-start" style="text-align: center">Heading 2</h2>',
        '<h3 style="text-align: center">Heading 3</h3>',
        '<p style="text-align: right">First paragraph</p>',
        '<p><s><em>Bonjour </em></s><u><strong>Paul</strong></u> <mark>!</mark></p>',
        '<ul><li>Item 1</li><li>Item 2</li></ul>',
        '<ol><li>Item 1</li><li>Item 2</li></ol>',
        '<p>Langages de prédilection:</p><ul><li>ruby</li><li>rust</li></ul>',
        '<footer>Footer</footer>',
      ].join
    end

    it 'returns html' do
      expect(described_class.new.to_html(json, substitutions)).to eq(html)
    end

    context 'body start on paragraph' do
      let(:json) do
        {
          type: 'doc',
          content: [
            {
              type: 'title',
              content: [{ type: 'text', text: 'The Title' }],
            },
            {
              type: 'paragraph',
              content: [{ type: 'text', text: 'First paragraph' }],
            },
          ],
        }
      end

      it 'defines stat body on first paragraph' do
        expect(described_class.new.to_html(json, substitutions)).to eq("<h1>The Title</h1><p class=\"body-start\">First paragraph</p>")
      end
    end

    context 'hard break' do
      let(:json) do
        {
          type: 'doc',
          content: [
            {
              type: 'paragraph',
              content: [
                {
                  type: 'text',
                  text: 'Première ligne',
                },
                {
                  type: 'hardBreak',
                },
                {
                  type: 'text',
                  text: 'Seconde ligne',
                },
              ],
            },
          ],
        }
      end

      it 'renders a blank line' do
        expect(described_class.new.to_html(json, {})).to eq(
          '<p class="body-start">Première ligne<br><br>Seconde ligne</p>'
        )
      end
    end

    context 'link mark' do
      let(:json) do
        {
          type: 'doc',
          content: [
            {
              type: 'paragraph',
              content: [
                {
                  type: 'text',
                  text: 'Cliquez ',
                },
                {
                  type: 'text',
                  text: 'ici',
                  marks: [{ type: 'link', attrs: { href: 'https://example.com' } }],
                },
                {
                  type: 'text',
                  text: ' pour continuer.',
                },
              ],
            },
          ],
        }
      end

      it 'renders link with security attributes' do
        expect(described_class.new.to_html(json, {})).to eq(
          '<p class="body-start">Cliquez <a href="https://example.com" target="_blank" rel="noopener noreferrer">ici</a> pour continuer.</p>'
        )
      end

      context 'with XSS attempt in href' do
        let(:json) do
          {
            type: 'doc',
            content: [
              {
                type: 'paragraph',
                content: [
                  {
                    type: 'text',
                    text: 'link',
                    marks: [{ type: 'link', attrs: { href: '"><script>alert(1)</script>' } }],
                  },
                ],
              },
            ],
          }
        end

        it 'escapes malicious href' do
          expect(described_class.new.to_html(json, {})).to include('&quot;&gt;&lt;script&gt;')
        end
      end
    end

    context 'page break node' do
      let(:json) do
        {
          type: 'doc',
          content: [
            { type: 'paragraph', content: [{ type: 'text', text: 'Avant' }] },
            { type: 'pageBreak' },
            { type: 'paragraph', content: [{ type: 'text', text: 'Après' }] },
          ],
        }
      end

      it 'renders a page-break div without consuming the body-start mark' do
        expect(described_class.new.to_html(json)).to eq(
          '<p class="body-start">Avant</p><div class="page-break"></div><p>Après</p>'
        )
      end

      it 'does not render a page-break div when it is the first node' do
        json = {
          type: 'doc',
          content: [
            { type: 'pageBreak' },
            { type: 'paragraph', content: [{ type: 'text', text: 'Premier paragraphe' }] },
          ],
        }
        expect(described_class.new.to_html(json)).to eq(
          '<p class="body-start">Premier paragraphe</p>'
        )
      end
    end

    context 'ordered list with custom classes' do
      let(:json) do
        {
          type: 'doc',
          content: [
            {
              type: 'orderedList',
              attrs: { class: "my-class" },
              content: [
                {
                  type: 'listItem',
                  content: [
                    {
                      type: 'paragraph',
                      content: [
                        {
                          type: 'text',
                          text: 'Item 1',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        }
      end

      it "set class attribute" do
        expect(described_class.new.to_html(json, substitutions)).to eq('<ol class="my-class"><li>Item 1</li></ol>')
      end
    end
  end

  describe '#used_tags' do
    it 'returns used tags' do
      expect(described_class.used_tags_and_libelle_for(json)).to eq(Set.new([['name', 'Nom'], ['languages', 'Langages']]))
    end
  end

  describe 'sanitization' do
    it 'escapes HTML tags in text content' do
      json = { type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: '<script>alert(1)</script>' }] }] }
      expect(described_class.new.to_html(json, {})).to include('&lt;script&gt;')
    end

    it 'ignores unknown node types' do
      json = { type: 'doc', content: [{ type: 'paragraph', content: [{ type: 'text', text: 'Hello' }] }, { type: 'script', content: [{ type: 'text', text: 'evil' }] }] }
      result = described_class.new.to_html(json, {})
      expect(result).to include('Hello')
      expect(result).not_to include('evil')
    end
  end

  describe '.to_texts_and_tags' do
    subject { described_class.new.to_texts_and_tags(json, substitutions) }

    context 'nominal' do
      let(:json) do
        {
          "content" => [
            { "type" => "paragraph", "content" => [{ "text" => "export_", "type" => "text" }, { "type" => "mention", "attrs" => { "id" => "dossier_number", "label" => "numéro du dossier" } }, { "text" => " .pdf", "type" => "text" }] },
          ],

        }.deep_symbolize_keys
      end

      context 'with substitutions' do
        let(:substitutions) { { "dossier_number" => "42" } }
        it 'returns texts_and_tags' do
          is_expected.to eq("export_42.pdf")
        end
      end

      context 'without substitutions' do
        let(:substitutions) { nil }

        it 'returns texts_and_tags' do
          is_expected.to eq("export_<span class='fr-tag fr-tag--sm'>numéro du dossier</span>.pdf")
        end
      end
    end

    context 'empty paragraph' do
      let(:json) { { content: [{ type: 'paragraph' }] } }
      let(:substitutions) { {} }

      it { is_expected.to eq('') }
    end

    context 'pageBreak node' do
      let(:substitutions) { {} }

      it 'renders a space between paragraphs separated by a pageBreak' do
        json = {
          type: 'doc',
          content: [
            { type: 'paragraph', content: [{ type: 'text', text: 'Avant' }] },
            { type: 'pageBreak' },
            { type: 'paragraph', content: [{ type: 'text', text: 'Après' }] },
          ],
        }
        expect(described_class.new.to_texts_and_tags(json)).to eq('Avant Après')
      end
    end
  end

  describe '#to_text' do
    let(:doc) do
      {
        type: 'doc',
        content: [
          {
            type: 'paragraph',
            content: [
              { type: 'text', text: 'Dossier nº ' },
              { type: 'mention', attrs: { id: 'dossier_number', label: 'numéro du dossier' } },
              { type: 'text', text: ' reçu' },
            ],
          },
        ],
      }
    end

    it 'concatène le texte en préservant les espaces et substitue les mentions' do
      result = TiptapService.new.to_text(doc, { 'dossier_number' => '42' })
      expect(result).to eq('Dossier nº 42 reçu')
    end

    it 'affiche --id-- pour une mention non substituée' do
      result = TiptapService.new.to_text(doc, {})
      expect(result).to eq('Dossier nº --dossier_number-- reçu')
    end

    it 'retourne une chaîne vide pour nil' do
      expect(TiptapService.new.to_text(nil)).to eq('')
    end
  end
end
