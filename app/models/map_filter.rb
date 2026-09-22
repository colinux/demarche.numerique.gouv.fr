# frozen_string_literal: true

class MapFilter
  include ActiveModel::Model
  include ActiveModel::Attributes

  KINDS = ["nb_demarches", "nb_dossiers"].freeze

  # Palette steps, lightest to darkest (see map_info.scss)
  LEVELS = [:nothing, :small, :medium, :large, :xlarge].freeze

  Bin = Data.define(:css_class, :min, :max)

  YEARS_INTERVAL = 2018..Date.current.year

  attr_accessor :stats

  attribute :year, :integer
  validates :year, numericality: { only_integer: true, greater_than_or_equal_to: YEARS_INTERVAL.begin, less_than_or_equal_to: YEARS_INTERVAL.end }

  attribute :kind, default: "nb_demarches"
  validates :kind, inclusion: { in: KINDS }

  def kind_buttons
    KINDS.map do
      { label: I18n.t("kind.#{it}", scope:), value: it }
    end
  end

  # Bins are quintiles of the displayed values: each color covers about a fifth
  # of the départements, whatever the year or the kind, so the map stays
  # contrasted as volumes grow. Ties collapse bins, so there may be fewer than
  # LEVELS.size of them.
  def legend
    @legend ||= build_legend
  end

  def css_class_for_departement(departement)
    value = value_for_departement(departement)
    legend.reverse.find { value >= it.min }.css_class
  end

  def nb_demarches_for_departement(departement)
    stats[departement.upcase] ? stats[departement.upcase][:nb_demarches] : 0
  end

  def nb_dossiers_for_departement(departement)
    stats[departement.upcase] ? stats[departement.upcase][:nb_dossiers] : 0
  end

  def label_for(bin)
    min = ActiveSupport::NumberHelper.number_to_delimited(bin.min)
    if bin.max
      I18n.t(:legend, min_thresold: min, max_thresold: ActiveSupport::NumberHelper.number_to_delimited(bin.max), scope:)
    else
      I18n.t(:legend_last, min_thresold: min, scope:)
    end
  end

  def detailed_title
    add_on = I18n.t(:specific_year_add_on, year:, scope:) if year
    I18n.t("detailed_title_for_#{kind}", add_on:, scope:)
  end

  private

  def value_for_departement(departement)
    kind == "nb_demarches" ? nb_demarches_for_departement(departement) : nb_dossiers_for_departement(departement)
  end

  def build_legend
    values = stats.except(nil).values.map { it[kind.to_sym] }.sort
    # Lower bounds: 0 (départements without data), then the values sitting at
    # 20 %, 40 %, 60 % and 80 % of the sorted list.
    mins = ([0] + (1...LEVELS.size).map { values[it * values.size / LEVELS.size] }).compact.uniq
    css_classes = spread_levels(mins.size)

    mins.each_with_index.map do |min, index|
      next_min = mins[index + 1]
      Bin.new(css_class: css_classes[index], min:, max: next_min && next_min - 1)
    end
  end

  # Fewer bins than colors: keep the lightest and the darkest, spread the rest.
  def spread_levels(count)
    return [LEVELS.first] if count == 1

    (0...count).map { LEVELS[(it * (LEVELS.size - 1)).fdiv(count - 1).round] }
  end

  def scope
    'activemodel.attributes.map_filter'
  end
end
