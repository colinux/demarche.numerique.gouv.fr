# frozen_string_literal: true

describe Columns::CheckboxColumn do
  let(:procedure) { create(:procedure, public_type_de_champs: [{ type: :checkbox, libelle: 'checkbox' }, { type: :yes_no, libelle: 'yes_no' }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:column) { procedure.find_column(label: 'checkbox') }
  let(:champ) { dossier.champ_data.find(&:checkbox?) }

  it { expect(column).to be_a(described_class) }

  describe '#value' do
    subject { column.value(champ) }

    context 'when nobody touched the checkbox' do
      it { is_expected.to be(false) }
    end

    context 'when the checkbox was checked then unchecked' do
      before { champ.update(value: 'false') }

      it { is_expected.to be(false) }
    end

    context 'when the checkbox is checked' do
      before { champ.update(value: 'true') }

      it { is_expected.to be(true) }
    end

    context 'when the dossier has no champ' do
      let(:champ) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the champ was last written as an unanswered yes/no' do
      let(:champ) { dossier.champ_data.find(&:yes_no?) }

      it { is_expected.to be(false) }
    end
  end

  describe 'a yes/no column' do
    let(:column) { procedure.find_column(label: 'yes_no') }
    let(:champ) { dossier.champ_data.find(&:yes_no?) }

    it 'keeps its empty state' do
      expect(column).not_to be_a(described_class)
      expect(column.value(champ)).to be_nil
    end
  end
end
