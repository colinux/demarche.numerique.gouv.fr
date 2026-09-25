# frozen_string_literal: true

module Maintenance
  class T20260924normalizeProcedureLinksTask < MaintenanceTasks::Task
    # Documentation: cette tâche normalise les liens des démarches (notice, DPO,
    # webhook) comme le fait désormais la saisie : espaces autour retirés,
    # https:// ajouté à un lien sans schéma, préfixe mailto: retiré d'un email.
    # Un lien que la normalisation ne rend pas valide est laissé tel quel.

    include RunnableOnDeployConcern
    include StatementsHelpersConcern

    # Uncomment only if this task MUST run imperatively on its first deployment.
    # If possible, leave commented for manual execution later.
    # run_on_first_deploy

    LINKS = [:lien_notice, :lien_dpo, :web_hook_url].freeze

    def collection
      LINKS.map { Procedure.with_discarded.where.not(it => nil) }.reduce(:or)
    end

    def process(procedure)
      normalized = LINKS
        .index_with { Procedure.normalize_value_for(it, procedure[it]) }
        .reject { |link, value| value == procedure[link] || !url_valid?(procedure, link, value) }

      procedure.update_columns(normalized) if normalized.any?
    end

    def count
      collection.count
    end

    private

    # the url validator alone: the other attributes do not matter here
    def url_valid?(procedure, link, value)
      return true if value.nil?

      procedure.errors.clear
      Procedure.validators_on(link).each { it.validate_each(procedure, link, value) }
      procedure.errors.empty?
    end
  end
end
