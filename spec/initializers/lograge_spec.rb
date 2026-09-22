# frozen_string_literal: true

describe LogstashFormatter do
  before { freeze_time }

  it 'adds the logstash fields to the request payload' do
    data = { method: 'GET', path: '/dossiers/1', controller: 'Users::DossiersController', action: 'show', status: 200 }

    expect(JSON.parse(described_class.new.call(data))).to eq(
      'method' => 'GET',
      'path' => '/dossiers/1',
      'controller' => 'Users::DossiersController',
      'action' => 'show',
      'status' => 200,
      '@timestamp' => Time.current.utc.as_json,
      '@version' => '1',
      'message' => '[200] GET /dossiers/1 (Users::DossiersController#show)'
    )
  end
end
