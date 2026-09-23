# frozen_string_literal: true

describe TypeDeChampTreeType do
  let(:type) { described_class.new }
  let(:tree) { TypeDeChampTree.new(public_children: [TypeDeChampNode.new(stable_id: 1, type_de_champ_id: 10)], private_children: []) }
  let(:json) { { 'public_children' => [{ 'stable_id' => 1, 'type_de_champ_id' => 10, 'children' => [] }], 'private_children' => [] } }

  describe '#cast' do
    it 'accepts a tree, its JSON and the JSON document' do
      expect(type.cast(nil)).to be_nil
      expect(type.cast(tree)).to equal(tree)
      expect(type.cast(json)).to eq(tree)
      expect(type.cast(JSON.generate(json))).to eq(tree)
    end

    it 'rejects anything else' do
      expect { type.cast(1) }.to raise_error(ArgumentError)
    end
  end

  describe '#deserialize' do
    it 'loads the stored JSON document' do
      expect(type.deserialize(nil)).to be_nil
      expect(type.deserialize(JSON.generate(json))).to eq(tree)
    end
  end

  describe '#serialize' do
    it 'stores a tree as a JSON document' do
      expect(type.serialize(nil)).to be_nil
      expect(JSON.parse(type.serialize(tree))).to eq(json)
    end

    it 'rejects anything but a tree' do
      expect { type.serialize(json) }.to raise_error(ArgumentError)
    end
  end
end
