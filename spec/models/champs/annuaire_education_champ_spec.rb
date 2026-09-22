# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Champs::AnnuaireEducationChamp do
  include Dry::Monads[:result]

  describe '#fetch_external_data' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :annuaire_education }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.champ_data.first }

    subject { champ.fetch_external_data }

    context 'when a record is found' do
      let(:params) do
        {
          'nom_etablissement' => 'École primaire des Lilas',
          'identifiant_de_l_etablissement' => '0241348K',
          'siren_siret' => '21240037800254',
          'nom_commune' => 'Bergerac',
          'code_commune' => '24037',
          'code_departement' => '024',
          'libelle_departement' => 'Dordogne',
          'libelle_academie' => 'Bordeaux',
          'code_academie' => '04',
          'libelle_nature' => 'ECOLE DE NIVEAU ELEMENTAIRE',
          'code_nature' => 151,
          'type_contrat_prive' => 'SANS OBJET',
          'nombre_d_eleves' => 120,
          'adresse_1' => '4 route de Montpon',
          'code_postal' => '24100',
          'libelle_region' => 'Nouvelle-Aquitaine',
          'code_region' => '75',
          'telephone' => '0553570866',
          'mail' => 'ce.0241348K@ac-bordeaux.fr',
          'web' => 'https://ecole-des-lilas.example',
        }
      end

      before { allow_any_instance_of(APIEducation::AnnuaireEducationAdapter).to receive(:to_params).and_return(params) }

      it {
        is_expected.to eq(Success(data: params, value_json: {
          'nom_etablissement' => 'École primaire des Lilas',
          'identifiant_etablissement' => '0241348K',
          'siren_siret' => '21240037800254',
          'street_address' => '4 route de Montpon',
          'postal_code' => '24100',
          'city_name' => 'Bergerac',
          'city_code' => '24037',
          'department_code' => '24',
          'region_code' => '75',
          'academie' => 'Bordeaux (04)',
          'nature_etablissement' => 'ECOLE DE NIVEAU ELEMENTAIRE (151)',
          'type_contrat_prive' => nil,
          'nombre_eleves' => 120,
          'telephone' => '0553570866',
          'email' => 'ce.0241348K@ac-bordeaux.fr',
          'site_internet' => 'https://ecole-des-lilas.example',
        }))
      }

      # The éducation API pads metropolitan department codes to 3 characters,
      # unlike the INSEE codes used everywhere else in the app.
      context 'with a Corse department code' do
        let(:params) { super().merge('code_departement' => '02A', 'libelle_departement' => 'Corse-du-Sud') }

        it { expect(subject.success[:value_json]['department_code']).to eq('2A') }
      end

      context 'with an overseas department code (already 3 characters, no leading zero)' do
        let(:params) { super().merge('code_departement' => '972', 'libelle_departement' => 'Martinique') }

        it { expect(subject.success[:value_json]['department_code']).to eq('972') }
      end

      context 'with an unpadded department code, as the oldest rows hold it' do
        let(:params) { super().merge('code_departement' => '05', 'libelle_departement' => 'Hautes-Alpes') }

        it { expect(subject.success[:value_json]['department_code']).to eq('05') }
      end

      context 'with a department code our referential does not know' do
        let(:params) { super().merge('code_departement' => '0XX', 'libelle_departement' => 'Nulle part') }

        it { expect(subject.success[:value_json]['department_code']).to be_nil }
      end
    end

    context 'when no record is found' do
      before { allow_any_instance_of(APIEducation::AnnuaireEducationAdapter).to receive(:to_params).and_return(nil) }

      it 'returns a non-retryable not found failure' do
        expect(subject).to be_failure
        expect(subject.failure[:retryable]).to eq(false)
        expect(subject.failure[:code]).to eq(404)
        expect(subject.failure[:error].message).to eq('NotFound')
      end
    end

    context 'when the API call fails' do
      before { allow_any_instance_of(APIEducation::AnnuaireEducationAdapter).to receive(:to_params).and_raise(APIEducation::API::RequestFailedError) }

      it 'returns a retryable failure' do
        expect(subject).to be_failure
        expect(subject.failure[:retryable]).to eq(true)
        expect(subject.failure[:code]).to eq(503)
        expect(subject.failure[:error]).to be_a(APIEducation::API::RequestFailedError)
      end
    end

    context 'when the response does not match the expected schema' do
      before { allow_any_instance_of(APIEducation::AnnuaireEducationAdapter).to receive(:to_params).and_raise(APIEducation::AnnuaireEducationAdapter::InvalidSchemaError.new([])) }

      it 'returns a non-retryable failure' do
        expect(subject).to be_failure
        expect(subject.failure[:retryable]).to eq(false)
        expect(subject.failure[:code]).to eq(422)
        expect(subject.failure[:error]).to be_a(APIEducation::AnnuaireEducationAdapter::InvalidSchemaError)
      end
    end
  end

  describe '#update_external_data!' do
    let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :annuaire_education }]) }
    let(:dossier) { create(:dossier, :with_populated_champs, procedure:) }
    let(:champ) { dossier.champ_data.first.tap { _1.update_column(:data, 'any data') } }
    subject { champ.send(:update_external_data!, data: data) }

    shared_examples "a data updater (without updating the value)" do |data|
      it do
        expect { subject }.to change { champ.reload.data }.to(data)
        expect { subject }.not_to change { champ.reload.value }
      end
    end

    context 'when data is nil' do
      let(:data) { nil }
      it_behaves_like "a data updater (without updating the value)", nil
    end

    context 'when data is empty' do
      let(:data) { '' }
      it_behaves_like "a data updater (without updating the value)", ''
    end

    context 'when data is consistent' do
      let(:data) {
        {
          'nom_etablissement' => "karrigel an ankou",
          'nom_commune' => 'kumun',
          'identifiant_de_l_etablissement' => '666667',
        }
      }
      it_behaves_like "a data updater (without updating the value)", {
        'nom_etablissement' => "karrigel an ankou",
        'nom_commune' => 'kumun',
        'identifiant_de_l_etablissement' => '666667',
      }
    end
  end
end
