# frozen_string_literal: true

describe MapFilter do
  let(:params) { { kind: "nb_dossiers" } }
  let(:map_filter) do
    mf = MapFilter.new(params)
    mf.stats = stats
    mf
  end

  def stats_for(dossiers_by_departement)
    dossiers_by_departement.transform_values { { nb_demarches: 1, nb_dossiers: it } }
  end

  describe '#legend' do
    context 'with ten départements of distinct volumes' do
      let(:stats) { stats_for((1..10).to_h { [format('%02d', it), it * 1000] }) }

      it 'splits them in quintiles, one color each' do
        expect(map_filter.legend).to eq([
          MapFilter::Bin.new(css_class: :nothing, min: 0, max: 2999),
          MapFilter::Bin.new(css_class: :small, min: 3000, max: 4999),
          MapFilter::Bin.new(css_class: :medium, min: 5000, max: 6999),
          MapFilter::Bin.new(css_class: :large, min: 7000, max: 8999),
          MapFilter::Bin.new(css_class: :xlarge, min: 9000, max: nil),
        ])
      end

      it 'colors each département by its bin, absent ones as the lightest' do
        expect(map_filter.css_class_for_departement('01')).to eq :nothing
        expect(map_filter.css_class_for_departement('03')).to eq :small
        expect(map_filter.css_class_for_departement('10')).to eq :xlarge
        expect(map_filter.css_class_for_departement('2a')).to eq :nothing
      end
    end

    context 'with ties' do
      let(:stats) { stats_for('01' => 0, '02' => 0, '03' => 0, '04' => 0, '05' => 500) }

      it 'collapses the bins and keeps the extreme colors' do
        expect(map_filter.legend).to eq([
          MapFilter::Bin.new(css_class: :nothing, min: 0, max: 499),
          MapFilter::Bin.new(css_class: :xlarge, min: 500, max: nil),
        ])
      end
    end

    context 'without data' do
      let(:stats) { {} }

      it 'has a single bin' do
        expect(map_filter.legend).to eq([MapFilter::Bin.new(css_class: :nothing, min: 0, max: nil)])
        expect(map_filter.css_class_for_departement('75')).to eq :nothing
      end
    end

    context 'for nb_demarches' do
      let(:params) { { kind: "nb_demarches" } }
      let(:stats) { { '63' => { nb_demarches: 51, nb_dossiers: 2001 }, '75' => { nb_demarches: 3, nb_dossiers: 9000 } } }

      it 'bins on the number of procedures' do
        expect(map_filter.css_class_for_departement('63')).to eq :xlarge
        expect(map_filter.css_class_for_departement('75')).to eq :medium
      end
    end
  end

  describe '#label_for' do
    let(:stats) { stats_for('01' => 1500, '02' => 25000) }

    it 'formats the bounds' do
      first, middle, last = map_filter.legend
      expect(map_filter.label_for(first)).to eq "Entre 0 et 1 499"
      expect(map_filter.label_for(middle)).to eq "Entre 1 500 et 24 999"
      expect(map_filter.label_for(last)).to eq "25 000 et plus"
    end
  end
end
