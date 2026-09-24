# frozen_string_literal: true

class RemoveDossiersSearchTermsExpressionIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :dossiers, name: :index_dossiers_on_search_terms, algorithm: :concurrently, if_exists: true
    remove_index :dossiers, name: :index_dossiers_on_search_terms_private_search_terms, algorithm: :concurrently, if_exists: true
  end

  def down
    add_index :dossiers, "to_tsvector('french_unaccent', search_terms)",
      name: :index_dossiers_on_search_terms,
      using: :gin,
      algorithm: :concurrently,
      if_not_exists: true

    add_index :dossiers, "to_tsvector('french_unaccent', search_terms || ' ' || private_search_terms)",
      name: :index_dossiers_on_search_terms_private_search_terms,
      using: :gin,
      algorithm: :concurrently,
      if_not_exists: true
  end
end
