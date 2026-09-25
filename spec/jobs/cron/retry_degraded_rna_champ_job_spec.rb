# frozen_string_literal: true

RSpec.describe Cron::RetryDegradedRNAChampJob, type: :job do
  let(:procedure) { create(:procedure, :published, public_type_de_champs: [{ type: :rna }]) }
  let(:dossier) { create(:dossier, procedure:) }
  let(:champ) { dossier.champ_data.first }

  before do
    champ.update_columns(external_id: 'W182736273', value: 'W182736273', external_state: 'degraded')
    allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:djepva_association).and_return(provider_up)
  end

  context 'once the association API answers again' do
    let(:provider_up) { true }

    it 'puts the champ back in the queue' do
      expect { described_class.perform_now }
        .to change { champ.reload.external_state }.from('degraded').to('waiting_for_fix')
    end

    it 'does not make the dossier look freshly modified to its instructeur' do
      expect { described_class.perform_now }.not_to change { dossier.reload.updated_at }
    end
  end

  context 'while the association API is still down' do
    let(:provider_up) { false }

    it 'leaves it alone' do
      expect { described_class.perform_now }.not_to change { champ.reload.external_state }
    end
  end

  describe 'schedule' do
    let(:provider_up) { true }

    it 'runs half an hour off the siret job, so the two spreads never overlap' do
      expect(described_class.cron_expression).to start_with('30 ')
      expect(Cron::RetryDegradedSiretChampJob.cron_expression).to start_with('0 ')
    end
  end
end
