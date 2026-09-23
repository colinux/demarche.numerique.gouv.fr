# frozen_string_literal: true

# Oaken seeds (db/seeds/) replace ActiveRecord fixtures. oaken/rspec_setup
# replants them (truncate + load users, procedures, dossiers) once per suite
# and includes the labeled-record accessors (users.usager, procedures.individual,
# dossiers.en_construction, …) in every example; per-example mutations roll
# back via transactional fixtures. Scenario seeds (db/seeds/cases/) still load
# per group with `before_all { seed "cases/sva" }`.
#
# A type de champ created without a stable_id (add_type_de_champ, seeds) takes
# its id as stable_id (TypeDeChamp#populate_stable_id), while many specs pick
# small stable_ids by hand. On a fresh CI database the id sequence starts at 1
# and eventually hits those values, and two types de champ of one revision
# share a stable_id. Start the sequence far above them, and above the factory's
# stable_id sequence, before the seeds are planted.
RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.connection.execute("SELECT setval('types_de_champ_id_seq', GREATEST(10000000, (SELECT last_value FROM types_de_champ_id_seq)))")
  end
end

require 'oaken/rspec_setup'

# Specs asserting on global aggregates or unparameterized scopes (raw SQL over
# a whole table, `Dossier.some_scope`, `Procedure.all`) can't scope their
# queries to spec-created records. Declare the models whose tables must start
# empty at the top of the group, before any `let_it_be`:
#
#   describe '.dossiers_states' do
#     empty_seeds Dossier
#
# All rows of the given models are destroyed once per group, inside the
# group's before_all transaction: examples start from an empty table and the
# seeded world comes back when the group's transaction rolls back. List
# dependents before their parents (e.g. `empty_seeds Dossier, Procedure` —
# procedures restrict deletion while dossiers exist). Seed accessors for the
# wiped models (dossiers.en_construction, …) must not be used in the group.
module EmptySeeds
  def empty_seeds(*models)
    # unscoped: the wipe must also remove rows hidden by default scopes (discarded procedures)
    before_all { models.each { it.unscoped.destroy_all } } # rubocop:disable DS/Unscoped
  end
end

RSpec.configure do |config|
  config.extend EmptySeeds
end
