# frozen_string_literal: true

class TiptapEditorComponent < ApplicationComponent
  DEFAULT_ACTIONS = %w[bold italic bulletList orderedList link].freeze

  BUTTONS = {
    'bold' => { label: 'Gras', title: 'Gras', icon: 'fr-icon-bold' },
    'italic' => { label: 'Italique', title: 'Italique', icon: 'fr-icon-italic' },
    'strike' => { label: 'Barré', title: 'Barré', icon: nil },
    'heading2' => { label: 'Titre', title: 'Titre', icon: nil },
    'heading3' => { label: 'Sous-titre', title: 'Sous-titre', icon: nil },
    'bulletList' => { label: 'Liste', title: 'Liste à puces', icon: 'fr-icon-list-unordered' },
    'orderedList' => { label: 'Numérotée', title: 'Liste numérotée', icon: 'fr-icon-list-ordered' },
  }.freeze

  attr_reader :form, :field_name, :preview_url, :actions

  def initialize(form:, field_name:, preview_url: nil, actions: DEFAULT_ACTIONS)
    @form = form
    @field_name = field_name
    @preview_url = preview_url
    @actions = actions
  end

  def input_value
    form.object.public_send("#{field_name}_or_default")
  end

  def simple_buttons
    actions.filter_map { |action| BUTTONS[action]&.merge(action: action) }
  end

  def link?
    actions.include?('link')
  end

  def button_class(button)
    ['fr-btn', 'fr-btn--secondary', 'fr-btn--sm', button[:icon]].compact.join(' ')
  end

  def data_attributes
    attributes = { controller: 'tiptap' }
    attributes[:tiptap_preview_url_value] = preview_url if preview_url
    attributes
  end
end
