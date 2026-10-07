# frozen_string_literal: true

RSpec.describe Columns::DemandeurSiretColumn do
  let(:procedure) { procedures.entreprise }
  let(:column) { procedure.find_column(label: 'Établissement SIRET') }
  let(:unverified) { dossiers.entreprise_en_instruction }
  let(:verified) { dossiers.avec_siret }
  let(:scope) { Dossier.where(id: [unverified.id, verified.id]) }

  before do
    unverified.etablissement.destroy!
    unverified.reload.create_demandeur_siret!(siret: '30613890001294', external_state: 'degraded')
    unverified.reload
  end

  it 'keeps the id saved in procedure presentations and export templates' do
    expect(column).to be_a(described_class)
    expect(column.h_id[:column_id]).to eq('etablissement/siret')
  end

  it 'reads the etablissement, or the unverified SIRET without one' do
    expect(column.value(unverified)).to eq('30613890001294')
    expect(column.value(verified)).to eq(verified.etablissement.siret)
  end

  it 'filters on both' do
    expect(column.filtered_ids(scope, { operator: 'match', value: ['3061389'] })).to eq([unverified.id])
    expect(column.filtered_ids(scope, { operator: 'match', value: [verified.etablissement.siret.first(7)] })).to eq([verified.id])
  end

  it 'sorts on both' do
    expected = [unverified, verified].sort_by(&:siret).map(&:id)

    expect(column.sorted_ids(scope, 'asc')).to eq(expected)
    expect(column.sorted_ids(scope, 'desc')).to eq(expected.reverse)
  end

  it 'is sorted the same way by the filter service' do
    sorted_column = SortedColumn.new(column:, order: 'desc')

    expect(DossierFilterService.sorted_ids(scope, sorted_column, instructeurs.default, nil))
      .to eq(column.sorted_ids(scope, 'desc'))
  end
end
