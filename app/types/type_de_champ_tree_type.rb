# frozen_string_literal: true

class TypeDeChampTreeType < ActiveRecord::Type::Value
  # value can come from:
  # setter: TypeDeChampTree, its JSON (Hash) or the JSON document (String)
  # from db: the JSON document (String)
  def cast(value)
    case value
    in TypeDeChampTree | NilClass
      value
    in Hash
      TypeDeChampTree.from_json(value)
    in String
      TypeDeChampTree.from_json(JSON.parse(value))
    else
      raise ArgumentError, "Invalid value for TypeDeChampTree casting: #{value}"
    end
  end

  # db -> ruby
  def deserialize(value) = cast(value)

  # ruby -> db
  def serialize(value)
    case value
    in NilClass
      nil
    in TypeDeChampTree
      JSON.generate(value.as_json)
    else
      raise ArgumentError, "Invalid value for TypeDeChampTree serialization: #{value}"
    end
  end
end
