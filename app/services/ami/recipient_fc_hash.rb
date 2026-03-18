# frozen_string_literal: true

require 'digest'

module Ami
  class RecipientFcHash
    REQUIRED_ATTRIBUTES = [:given_name, :family_name, :birthdate, :gender, :birthplace, :birthcountry].freeze

    class << self
      def call(user)
        france_connect_information = latest_france_connect_information_for(user)
        return if france_connect_information.blank?

        attributes = REQUIRED_ATTRIBUTES.map { value_for(france_connect_information, _1) }

        Digest::SHA256.hexdigest(attributes.join)
      end

      private

      def latest_france_connect_information_for(user)
        user&.france_connect_informations&.order(updated_at: :desc)&.first
      end

      def value_for(france_connect_information, attribute)
        value = france_connect_information.public_send(attribute)
        return value.iso8601 if attribute == :birthdate && value.respond_to?(:iso8601)

        value
      end
    end
  end
end
