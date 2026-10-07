# frozen_string_literal: true

RSpec.describe Cron::RetryDegradedDemandeurSiretJob, type: :job do
  let(:dossier) { create(:dossier, procedure: procedures.entreprise) }
  let!(:demandeur_siret) { DemandeurSiret.create!(dossier:, siret: '30613890001294', external_state:) }
  let(:external_state) { 'degraded' }
  let(:insee_up) { true }

  before do
    procedures.entreprise.update!(api_entreprise_token: JWT.encode({ exp: 2.months.from_now.to_i }, nil, 'none'))
    allow(APIEntreprise::HealthChecker).to receive(:provider_up?).with(:insee_sirene).and_return(insee_up)
  end

  it 'runs apart from the replays of the SIRET and RNA champs' do
    expect(described_class.cron_expression)
      .not_to be_in([Cron::RetryDegradedSiretChampJob.cron_expression, Cron::RetryDegradedRNAChampJob.cron_expression])
  end

  context 'with a degraded SIRET' do
    it 'schedules its retry' do
      expect { described_class.perform_now }
        .to change { demandeur_siret.reload.external_state }.from('degraded').to('waiting_for_fix')
        .and have_enqueued_job(FetchExternalDataJob).with(demandeur_siret, '30613890001294')
    end

    context 'while INSEE is still down' do
      let(:insee_up) { false }

      it { expect { described_class.perform_now }.not_to change { demandeur_siret.reload.external_state } }
    end

    context 'on a dossier hidden by the administration' do
      before { dossier.update_columns(hidden_by_administration_at: Time.current) }

      it { expect { described_class.perform_now }.not_to change { demandeur_siret.reload.external_state } }
    end

    context 'while the token of the procedure is rejected' do
      before { procedures.entreprise.update!(api_entreprise_token_rejected_at: Time.current) }

      it { expect { described_class.perform_now }.not_to change { demandeur_siret.reload.external_state } }
    end
  end

  context 'with a SIRET whose verification failed for good' do
    let(:external_state) { 'external_error' }

    it { expect { described_class.perform_now }.not_to have_enqueued_job(FetchExternalDataJob) }
  end
end
