# frozen_string_literal: true

class Dsfr::RadioButtonListComponent < ApplicationComponent
  attr_reader :error

  def initialize(form:, target:, buttons:, error: nil, inline: false, regular_legend: true)
    @form = form
    @target = target
    @buttons = buttons
    @error = error
    @inline = inline
    @regular_legend = regular_legend
    @id = "radio-#{target}-#{SecureRandom.hex(4)}"
  end

  def legend_id = "#{@id}-legend"
  def messages_id = "#{@id}-messages"

  def error?
    @error.present?
  end

  def disabled?
    @buttons.all? { _1[:disabled] }
  end

  def each_button
    @buttons.each.with_index do |button, index|
      yield(*button.values_at(:label, :value, :hint, :tooltip), **button.merge!(index:).except(:label, :value, :hint, :tooltip))
    end
  end

  def label_options(button_options)
    {
      for: button_options[:id],
    }.compact
  end
end
