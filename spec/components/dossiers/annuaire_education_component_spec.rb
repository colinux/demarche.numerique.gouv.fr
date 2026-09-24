# frozen_string_literal: true

RSpec.describe Dossiers::AnnuaireEducationComponent, type: :component do
  let(:champ) { double('Champ', value_json: annuaire_value_json) }

  let(:annuaire_value_json) do
    {
      'nom_etablissement' => 'Lycée Jean Moulin',
      'identifiant_etablissement' => '0123456A',
      'siren_siret' => '12345678901234',
      'street_address' => '123 rue de la République',
      'postal_code' => '75001',
      'city_name' => 'Paris',
      'city_code' => '75001',
      'department_code' => '75',
      'region_code' => '11',
      'academie' => 'Paris (01)',
      'nature_etablissement' => 'Lycée général (LGT)',
      'type_contrat_prive' => nil,
      'nombre_eleves' => '450',
      'telephone' => '0145123456',
      'email' => 'contact@lycee-moulin.fr',
      'site_internet' => 'https://lycee-moulin.fr',
    }
  end

  subject { render_inline(described_class.new(champ:)) }

  before do
    allow(Dossiers::ExternalChampComponent).to receive(:new).and_call_original
    subject
  end

  describe '#call' do
    it 'renders ExternalChampComponent with correct arguments' do
      expect(Dossiers::ExternalChampComponent).to have_received(:new) do |data:, details:, source:|
        expected_data = [
          ["Nom de l’établissement", "Lycée Jean Moulin"],
          ["L’identifiant de l’etablissement", "0123456A"],
          ["SIREN/SIRET", "12345678901234"],
        ]

        expected_details = [
          ["Commune", "Paris (75001)"],
          ["Académie", "Paris (01)"],
          ["Nature de l’établissement", "Lycée général (LGT)"],
          ["Type de contrat privé", nil],
          ["Nombre d’élèves", "450"],
          ["Adresse", "123 rue de la République<br>75001 Paris<br>Île-de-France (11)"],
          ["Téléphone", "0145123456"],
          ["Email", "contact@lycee-moulin.fr"],
          ["Site internet", "https://lycee-moulin.fr"],
        ]

        expected_source = "Annuaire de l’Éducation Nationale"

        expect(data).to eq(expected_data)
        expect(details).to eq(expected_details)
        expect(source).to eq(expected_source)
      end
    end

    context 'when the city_code is missing' do
      let(:annuaire_value_json) { super().merge({ 'city_code' => nil }) }

      it do
        expect(Dossiers::ExternalChampComponent).to have_received(:new) do |args|
          details = args[:details]
          expect(details.find { |label, _| label == 'Commune' }[1]).to eq('Paris')
        end
      end
    end

    context 'when the city_name is missing' do
      let(:annuaire_value_json) { super().merge({ 'city_name' => nil }) }

      it do
        expect(Dossiers::ExternalChampComponent).to have_received(:new) do |args|
          details = args[:details]
          expect(details.find { |label, _| label == 'Commune' }[1]).to eq("Non renseignée")
        end
      end
    end
  end
end
