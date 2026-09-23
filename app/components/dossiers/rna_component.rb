# frozen_string_literal: true

class Dossiers::RNAComponent < ApplicationComponent
  attr_reader :champ

  def initialize(champ:)
    @champ = champ
  end

  def call
    if champ.external_id.blank?
      tag.p(t('not_filled', scope: 'activerecord.attributes.type_de_champ'), class: "fr-mt-1w")
    elsif champ.fetched?
      render Dossiers::ExternalChampComponent.new(data:, details:, source:)
    elsif champ.pending?
      tag.p(t('shared.champs.external_data.pending', identifier: champ.external_id), class: "fr-mt-1w")
    elsif champ.awaiting_fix?
      tag.p(t('shared.champs.external_data.degraded', identifier: champ.external_id), class: "fr-mt-1w")
    elsif champ.external_data_not_found?
      tag.p(t('shared.champs.external_data.not_found', identifier: champ.external_id), class: "fr-mt-1w")
    elsif champ.external_error?
      tag.p(t('shared.champs.external_data.error', identifier: champ.external_id), class: "fr-mt-1w")
    end
  end

  private

  def data
    rows = [[champ.class.human_attribute_name(:value), champ.to_s]]
    return rows if champ.data.blank?

    rows + ['titre', 'objet'].map { label_value(it) }
  end

  def details
    return [] if champ.data.blank?

    [
      *['date_creation', 'date_declaration', 'date_publication'].map { label_value(it) },
      *helpers.address_array(champ),
    ]
  end

  def label_value(key)
    [champ.class.human_attribute_name("association_#{key}"), champ.data["association_#{key}"]]
  end

  def source
    tag.acronym("RNA", title: t(".rna_title"))
  end
end
