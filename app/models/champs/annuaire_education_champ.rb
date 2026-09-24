# frozen_string_literal: true

class Champs::AnnuaireEducationChamp < Champs::TextChamp
  def has_async_external_data?
    true
  end

  def fetch_external_data
    data = APIEducation::AnnuaireEducationAdapter.new(external_id).to_params

    if data.present?
      Success(data:, value_json: extract_value_json(data:))
    else
      Failure(retryable: false, error: StandardError.new('NotFound'), code: 404)
    end
  rescue APIEducation::API::RequestFailedError => error
    Failure(retryable: true, error:, code: 503)
  rescue APIEducation::AnnuaireEducationAdapter::InvalidSchemaError => error
    Failure(retryable: false, error:, code: 422)
  end

  def selected_items
    if external_id.present?
      [{ value: external_id, label: value }]
    else
      []
    end
  end

  # FIXME: temporary fallback for champs fetched before value_json existed
  # on this champ (data present, value_json nil). Remove once
  # MaintenanceTasks::BackfillAnnuaireEducationValueJsonTask has run in
  # production and every row has value_json persisted.
  def value_json
    super || (data.present? ? extract_value_json(data:) : nil)
  end

  private

  def extract_value_json(data:)
    {
      'nom_etablissement' => data['nom_etablissement'],
      'identifiant_etablissement' => data['identifiant_de_l_etablissement'],
      'siren_siret' => data['siren_siret'],
      'street_address' => data['adresse_1'],
      'postal_code' => data['code_postal'],
      'city_name' => data['nom_commune'],
      'city_code' => data['code_commune'],
      'department_code' => departement_code(data),
      'region_code' => data['code_region'],
      'academie' => academie(data),
      'nature_etablissement' => nature_etablissement(data),
      'type_contrat_prive' => type_contrat_prive(data),
      'nombre_eleves' => data['nombre_d_eleves'],
      'telephone' => data['telephone'],
      'email' => data['mail'],
      'site_internet' => data['web'],
    }
  end

  def academie(data)
    return if data['libelle_academie'].blank?

    "#{data['libelle_academie']} (#{data['code_academie']})"
  end

  def nature_etablissement(data)
    return if data['libelle_nature'].blank?

    "#{data['libelle_nature']} (#{data['code_nature']})"
  end

  def type_contrat_prive(data)
    data['type_contrat_prive'] if data['type_contrat_prive'] != 'SANS OBJET'
  end

  # The éducation API pads metropolitan department codes to 3 characters
  # ("024" for Dordogne, "02A" for Corse-du-Sud); older rows still hold the
  # unpadded INSEE code ("05"). Resolve the result against our own
  # referential: a code it does not know would never line up with the
  # Département filter options, so it is better left blank than stored as a
  # value nothing can read.
  def departement_code(data)
    code = data['code_departement']
    code = code.delete_prefix('0') if code&.size == 3

    APIGeoService.resolve_departement(code)&.code
  end
end
