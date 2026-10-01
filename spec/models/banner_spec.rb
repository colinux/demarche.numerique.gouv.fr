# frozen_string_literal: true

describe Banner do
  describe '#active?' do
    it 'est actif quand le contenu est présent, inactif sinon' do
      expect(Banner.new(content: 'Coucou').active?).to be(true)
      expect(Banner.new(content: '').active?).to be(false)
      expect(Banner.new(content: nil).active?).to be(false)
    end
  end

  describe '.cached_for', :caching do
    let!(:banner) { Banner.create!(target: 'global', content: 'V1') }

    it 'sert la valeur en cache puis la rafraîchit après mise à jour du record' do
      expect(Banner.cached_for('global').content).to eq('V1')

      # contourne les callbacks : le cache reste servi (preuve qu'il y a bien cache)
      Banner.where(id: banner.id).update_all(content: 'V2')
      expect(Banner.cached_for('global').content).to eq('V1')

      # update! déclenche le after_commit -> invalidation du cache
      banner.update!(content: 'V3')
      expect(Banner.cached_for('global').content).to eq('V3')
    end

    it 'ne renvoie rien quand la base est injoignable' do
      allow(Banner).to receive(:find_by).and_raise(ActiveRecord::DatabaseConnectionError.hostname_error('db'))

      expect(Banner.cached_for('global')).to be_nil
    end
  end
end
