# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260924RemoveSearchTermsTsvectorFeatureTask do
    let(:gates) { Flipper::Adapters::ActiveRecord::Gate }

    # En test l'adaptateur configuré est Flipper::Adapters::Memory, qui n'écrit
    # rien en base : on exerce l'adaptateur ActiveRecord de la production.
    before do
      @previous_flipper = Flipper.instance
      Flipper.instance = Flipper.new(Flipper::Adapters::ActiveRecord.new)
    end

    after { Flipper.instance = @previous_flipper }

    it 'never targets a flag the code still declares' do
      declared = Rails.root.join('config/initializers/flipper.rb').read
        .scan(/^\s*:(\w+),?\s*$/).flatten

      expect(described_class::OBSOLETE_FEATURES.map(&:to_s) & declared).to be_empty
    end

    it 'removes the fully-enabled flag and its gates' do
      Flipper.enable(:search_terms_tsvector)

      expect { described_class.process(:search_terms_tsvector) }
        .to change { gates.where(feature_key: 'search_terms_tsvector').count }.to(0)
      expect(Flipper.features.map(&:key)).not_to include('search_terms_tsvector')
    end
  end
end
