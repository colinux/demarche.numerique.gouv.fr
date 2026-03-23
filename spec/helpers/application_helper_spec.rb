# frozen_string_literal: true

describe ApplicationHelper do
  describe "#flash_class" do
    it do
      expect(flash_class('notice')).to eq 'alert-success fr-icon-success-line fr-icon--sm fr-text--sm fr-mb-0'
      expect(flash_class('alert', sticky: true, fixed: true)).to eq 'alert-danger fr-icon-error-line fr-icon--sm fr-text--sm fr-mb-0 sticky alert-fixed'
      expect(flash_class('error')).to eq 'alert-danger fr-icon-error-line fr-icon--sm fr-text--sm fr-mb-0'
      expect(flash_class('unknown-level')).to eq ''
    end
  end

  describe "#try_format_date" do
    subject { try_format_date(date) }

    describe 'try formatting a date' do
      let(:date) { Date.new(2019, 01, 24) }
      it { is_expected.to eq("24 janvier 2019") }
    end

    describe 'try formatting a blank string' do
      let(:date) { "" }
      it { is_expected.to eq("") }
    end

    describe 'try formatting a nil string' do
      let(:date) { nil }
      it { is_expected.to eq("") }
    end
  end

  describe "#try_format_datetime" do
    subject { try_format_datetime(datetime, format: :long_with_time) }

    describe 'try formatting 31/01/2019 11:25' do
      let(:datetime) { Time.zone.local(2019, 01, 31, 11, 25, 00) }
      it { is_expected.to eq("31 janvier 2019 à 11:25") }
    end

    describe 'try formatting a blank string' do
      let(:datetime) { "" }
      it { is_expected.to eq("") }
    end

    describe 'try formatting a nil string' do
      let(:datetime) { nil }
      it { is_expected.to eq("") }
    end
  end

  describe "#human_date" do
    subject { human_date(date) }

    describe 'human_date for today' do
      let(:date) { Date.today }
      it { is_expected.to eq("Aujourd’hui") }
    end
    describe 'human_date for yesterday' do
      let(:date) { Date.yesterday }
      it { is_expected.to eq("Hier") }
    end
    describe 'human_date for before yesterday' do
      let(:date) { Date.yesterday - 1 }
      it { is_expected.to eq("Il y a 2 jours") }
    end
    describe 'human_date for 24/01/2019' do
      let(:date) { Date.new(2019, 01, 24) }
      it { is_expected.to eq("24 janvier 2019") }
    end
  end

  describe '#acronymize' do
    it 'returns the acronym of a given string' do
      expect(helper.acronymize('Application Name')).to eq('AN')
      expect(helper.acronymize('Hello World')).to eq('HW')
      expect(helper.acronymize('Demarches Simplifiees')).to eq('DS')
      expect(helper.acronymize('demarche.numerique.gouv.fr')).to eq('DN')
      expect(helper.acronymize('demarches-simplifiees.fr')).to eq('DS')
      expect(helper.acronymize('demarches.adullact.org')).to eq('DA')
    end
  end
end
