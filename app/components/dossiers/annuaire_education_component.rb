# frozen_string_literal: true

class Dossiers::AnnuaireEducationComponent < ApplicationComponent
  attr_reader :champ

  def initialize(champ:)
    @champ = champ
  end

  def call
    render Dossiers::ExternalChampComponent.new(data:, details:, source:)
  end

  private

  def value_json = champ.value_json

  def data
    return [] if value_json.blank?

    [
      [t('.nom_etablissement'), value_json['nom_etablissement']],
      [t('.identifiant_etablissement'), value_json['identifiant_etablissement']],
      [t('.siren_siret'), value_json['siren_siret']],
    ]
  end

  def details
    return [] if value_json.blank?

    [
      [t('.commune'), commune],
      [t('.academie'), value_json['academie']],
      [t('.nature_etablissement'), value_json['nature_etablissement']],
      [t('.type_contrat_prive'), value_json['type_contrat_prive']],
      [t('.nombre_eleves'), value_json['nombre_eleves']],
      [t('.adresse'), adresse],
      [t('.telephone'), value_json['telephone']],
      [t('.email'), value_json['email']],
      [t('.site_internet'), value_json['site_internet']],
    ]
  end

  def commune
    if value_json['city_name'].present? && value_json['city_code'].present?
      "#{value_json['city_name']} (#{value_json['city_code']})"
    elsif value_json['city_name'].present?
      value_json['city_name']
    else
      t('.non_renseignee')
    end
  end

  def source = t('.source')

  def adresse
    safe_join([
      value_json['street_address'],
      value_json.values_at('postal_code', 'city_name').compact_blank.join(" "),
      region_libelle_and_code,
    ].compact, tag.br)
  end

  def region_libelle_and_code
    region_code = value_json['region_code']
    return if region_code.blank?

    region_name = APIGeoService.region_name(region_code)
    region_name.present? ? "#{region_name} (#{region_code})" : region_code
  end
end
