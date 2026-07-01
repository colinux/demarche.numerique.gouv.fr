# frozen_string_literal: true

describe TrixToTiptapService do
  let(:resolver) do
    -> (text) do
      text.split(/(--[^-]+--)/).filter_map do |part|
        if part.empty?
          nil
        elsif part.start_with?('--') && part.end_with?('--')
          id = part.delete('-')
          { "type" => "mention", "attrs" => { "id" => id, "label" => id } }
        else
          { "type" => "text", "text" => part }
        end
      end
    end
  end
  let(:service) { described_class.new(inline_resolver: resolver) }

  it 'convertit un paragraphe Trix simple' do
    doc = service.to_document('<div>Bonjour</div>')
    expect(doc).to eq({
      "type" => "doc",
      "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Bonjour" }] }],
    })
  end

  it 'convertit gras / italique / barré en marks' do
    doc = service.to_document('<div><strong>a</strong><em>b</em><del>c</del></div>')
    inline = doc["content"].first["content"]
    expect(inline).to eq([
      { "type" => "text", "text" => "a", "marks" => [{ "type" => "bold" }] },
      { "type" => "text", "text" => "b", "marks" => [{ "type" => "italic" }] },
      { "type" => "text", "text" => "c", "marks" => [{ "type" => "strike" }] },
    ])
  end

  it 'convertit un lien en mark link' do
    doc = service.to_document('<div><a href="https://x.fr">clic</a></div>')
    inline = doc["content"].first["content"]
    expect(inline).to eq([
      { "type" => "text", "text" => "clic", "marks" => [{ "type" => "link", "attrs" => { "href" => "https://x.fr" } }] },
    ])
  end

  it 'convertit une liste à puces' do
    doc = service.to_document('<ul><li>un</li><li>deux</li></ul>')
    expect(doc["content"]).to eq([
      {
        "type" => "bulletList",
        "content" => [
          { "type" => "listItem", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "un" }] }] },
          { "type" => "listItem", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "deux" }] }] },
        ],
      },
    ])
  end

  it 'convertit une liste ordonnée' do
    doc = service.to_document('<ol><li>un</li></ol>')
    expect(doc["content"].first["type"]).to eq("orderedList")
  end

  it 'convertit un titre Trix h1 en heading niveau 2' do
    doc = service.to_document('<h1>Titre</h1>')
    expect(doc["content"].first).to eq({
      "type" => "heading", "attrs" => { "level" => 2 },
      "content" => [{ "type" => "text", "text" => "Titre" }],
    })
  end

  it 'convertit un mention via le résolveur' do
    doc = service.to_document('<div>Nº --dossiernumber--</div>')
    expect(doc["content"].first["content"]).to eq([
      { "type" => "text", "text" => "Nº " },
      { "type" => "mention", "attrs" => { "id" => "dossiernumber", "label" => "dossiernumber" } },
    ])
  end

  it 'ignore le souligné (garde le texte)' do
    doc = service.to_document('<div><u>a</u></div>')
    expect(doc["content"].first["content"]).to eq([{ "type" => "text", "text" => "a" }])
  end

  it 'convertit <br> en hardBreak' do
    doc = service.to_document('<div>a<br>b</div>')
    expect(doc["content"].first["content"]).to eq([
      { "type" => "text", "text" => "a" },
      { "type" => "hardBreak" },
      { "type" => "text", "text" => "b" },
    ])
  end

  it 'retourne un doc avec paragraphe vide pour un HTML vide' do
    expect(service.to_document('')).to eq({ "type" => "doc", "content" => [{ "type" => "paragraph" }] })
  end
end
