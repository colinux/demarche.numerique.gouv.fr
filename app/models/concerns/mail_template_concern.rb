# frozen_string_literal: true

module MailTemplateConcern
  extend ActiveSupport::Concern

  include TagsSubstitutionConcern

  module Actions
    SHOW         = :show
    ASK_QUESTION = :ask_question
    REPLY        = :reply
  end

  EMPTY_TIPTAP_DOC = { "type" => "doc", "content" => [{ "type" => "paragraph" }] }.freeze

  def subject_for_dossier(dossier)
    if json_subject.present?
      render_tiptap_text(json_subject, dossier, escape: false)
    else
      replace_tags(subject, dossier, escape: false).presence || replace_tags(self.class::DEFAULT_SUBJECT, dossier, escape: false)
    end
  end

  def body_for_dossier(dossier)
    if json_body.present?
      render_tiptap_html(json_body, dossier)
    else
      replace_tags(body, dossier)
    end
  end

  def actions_for_dossier(dossier)
    [MailTemplateConcern::Actions::SHOW, MailTemplateConcern::Actions::ASK_QUESTION]
  end

  def attachment_for_dossier(dossier)
    nil
  end

  def update_rich_body
    self.rich_body = self.body
  end

  def tiptap_body
    json_body&.to_json
  end

  def tiptap_body=(json)
    self.json_body = JSON.parse(json)
  end

  def tiptap_subject
    json_subject&.to_json
  end

  def tiptap_subject=(json)
    self.json_subject = JSON.parse(json)
  end

  def tiptap_body_or_default
    if json_body.present?
      json_body.to_json
    elsif body.present?
      legacy_html_to_tiptap(body).to_json
    else
      EMPTY_TIPTAP_DOC.to_json
    end
  end

  def tiptap_subject_or_default
    if json_subject.present?
      json_subject.to_json
    else
      source = subject.presence || self.class::DEFAULT_SUBJECT
      { "type" => "doc", "content" => [{ "type" => "paragraph", "content" => tiptap_inline_nodes_for(source) }] }.to_json
    end
  end

  included do
    has_rich_text :rich_body
    before_save :update_rich_body
  end

  class_methods do
    def default_for_procedure(procedure)
      template_name = default_template_name_for_procedure(procedure)
      rich_body = ActionController::Base.render(template: template_name).gsub(/<!--.*?-->/m, '')
      trix_rich_body = rich_body.gsub(/(?<!^|[.-])(?<!<\/strong>)\n/, ' ')
      new(subject: const_get(:DEFAULT_SUBJECT), body: trix_rich_body, rich_body: trix_rich_body, procedure: procedure)
    end

    def default_template_name_for_procedure(procedure)
      const_get(:DEFAULT_TEMPLATE_NAME)
    end
  end

  def tiptap_inline_nodes_for(text)
    return [] if text.nil?

    parse_tags(text).filter_map do |token|
      case token
      in { tag:, id: }
        { "type" => "mention", "attrs" => { "id" => id, "label" => tag } }
      in { tag: }
        { "type" => "text", "text" => "--#{tag}--" }
      in { text: }
        { "type" => "text", "text" => text } unless text.empty?
      else
        nil
      end
    end
  end

  def dossier_tags
    super + TagsSubstitutionConcern::DOSSIER_TAGS_FOR_MAIL
  end

  private

  def legacy_html_to_tiptap(html)
    TrixToTiptapService.new(inline_resolver: method(:tiptap_inline_nodes_for)).to_document(html)
  end

  def render_tiptap_html(json, dossier, escape: true)
    node = json.deep_symbolize_keys
    used = TiptapService.used_tags_and_libelle_for(node)
    substitutions = tags_substitutions(used, dossier, escape:)
    TiptapService.new.to_html(node, substitutions)
  end

  def render_tiptap_text(json, dossier, escape: false)
    node = json.deep_symbolize_keys
    used = TiptapService.used_tags_and_libelle_for(node)
    substitutions = tags_substitutions(used, dossier, escape:)
    TiptapService.new.to_text(node, substitutions)
  end
end
