# frozen_string_literal: true

class TrixToTiptapService
  def initialize(inline_resolver:)
    @inline_resolver = inline_resolver
  end

  def to_document(html)
    fragment = Nokogiri::HTML.fragment(html.to_s)
    blocks = fragment.children.flat_map { block_nodes(_1) }
    blocks = [{ "type" => "paragraph" }] if blocks.empty?
    { "type" => "doc", "content" => blocks }
  end

  private

  def block_nodes(node)
    if node.text?
      text = node.text
      return [] if text.strip.empty?

      [paragraph(inline_from_string(text))]
    elsif node.element?
      case node.name
      when 'ul' then [{ "type" => "bulletList", "content" => list_items(node) }]
      when 'ol' then [{ "type" => "orderedList", "content" => list_items(node) }]
      when 'h1' then [{ "type" => "heading", "attrs" => { "level" => 2 }, "content" => inline_children(node, []) }]
      when 'br' then []
      when 'div', 'p', 'blockquote' then [paragraph(inline_children(node, []))]
      else
        nested = node.children.flat_map { block_nodes(_1) }
        nested.empty? ? [paragraph(inline_children(node, []))] : nested
      end
    else
      []
    end
  end

  def list_items(node)
    node.element_children.to_a.filter { _1.name == 'li' }.map do |li|
      { "type" => "listItem", "content" => [paragraph(inline_children(li, []))] }
    end
  end

  def paragraph(content)
    content.empty? ? { "type" => "paragraph" } : { "type" => "paragraph", "content" => content }
  end

  def inline_children(node, marks)
    node.children.flat_map { inline_nodes(_1, marks) }
  end

  def inline_nodes(node, marks)
    if node.text?
      inline_from_string(node.text, marks)
    elsif node.element?
      case node.name
      when 'strong', 'b' then inline_children(node, add_mark(marks, { "type" => "bold" }))
      when 'em', 'i' then inline_children(node, add_mark(marks, { "type" => "italic" }))
      when 'del', 's', 'strike' then inline_children(node, add_mark(marks, { "type" => "strike" }))
      when 'a' then inline_children(node, add_mark(marks, link_mark(node)))
      when 'br' then [{ "type" => "hardBreak" }]
      else inline_children(node, marks)
      end
    else
      []
    end
  end

  def inline_from_string(text, marks = [])
    @inline_resolver.call(text).map { |node| apply_marks(node, marks) }
  end

  def apply_marks(node, marks)
    return node if marks.empty?

    node.merge("marks" => marks)
  end

  def add_mark(marks, mark)
    marks + [mark]
  end

  def link_mark(node)
    { "type" => "link", "attrs" => { "href" => node["href"].to_s } }
  end
end
