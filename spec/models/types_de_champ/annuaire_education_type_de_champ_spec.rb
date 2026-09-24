# frozen_string_literal: true

describe TypesDeChamp::AnnuaireEducationTypeDeChamp do
  describe '#columns' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :annuaire_education, libelle: 'Établissement' }]) }
    let(:tdc) { procedure.active_revision.type_de_champs.first }
    let(:jsonpath_columns) { tdc.columns(procedure_id: procedure.id).grep(Columns::JSONPathColumn) }

    it 'exposes the standard addressable columns as displayable and filterable' do
      addressable = jsonpath_columns.filter { _1.jsonpath.start_with?('$.postal_code', '$.city_name', '$.department_code', '$.region_code') }
      expect(addressable.map(&:jsonpath)).to contain_exactly('$.postal_code', '$.city_name', '$.department_code', '$.region_code')
      expect(addressable).to all(have_attributes(displayable: true, filterable: true))
    end

    it 'exposes every other value_json field shown in the dossier view, as displayable' do
      extra = jsonpath_columns.reject { _1.jsonpath.start_with?('$.postal_code', '$.city_name', '$.department_code', '$.region_code') }
      expect(extra.map(&:jsonpath)).to contain_exactly(
        '$.nom_etablissement',
        '$.identifiant_etablissement',
        '$.siren_siret',
        '$.street_address',
        '$.city_code',
        '$.academie',
        '$.nature_etablissement',
        '$.type_contrat_prive',
        '$.nombre_eleves',
        '$.telephone',
        '$.email',
        '$.site_internet'
      )
      expect(extra).to all(have_attributes(displayable: true))
    end
  end
end
