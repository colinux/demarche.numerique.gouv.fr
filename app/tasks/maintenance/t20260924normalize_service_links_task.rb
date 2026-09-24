# frozen_string_literal: true

module Maintenance
  class T20260924normalizeServiceLinksTask < MaintenanceTasks::Task
    # Documentation: cette tâche normalise les liens des services (FAQ, page de
    # contact) comme le fait désormais la saisie : espaces autour retirés,
    # https:// ajouté à un lien sans schéma. Un lien que la normalisation ne
    # rend pas valide est laissé tel quel.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    LINKS = [:faq_link, :contact_link].freeze

    def collection
      LINKS.map { Service.where.not(it => nil) }.reduce(:or)
    end

    def process(service)
      normalized = LINKS
        .index_with { Service.normalize_value_for(it, service[it]) }
        .reject { |link, value| value == service[link] || !url_valid?(service, link, value) }

      service.update_columns(normalized) if normalized.any?
    end

    def count
      collection.count
    end

    private

    # the url validator alone: the other attributes do not matter here
    def url_valid?(service, link, value)
      return true if value.nil?

      service.errors.clear
      Service.validators_on(link).each { it.validate_each(service, link, value) }
      service.errors.empty?
    end
  end
end
