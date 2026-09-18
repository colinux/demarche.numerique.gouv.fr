# frozen_string_literal: true

RSpec.describe Capybara::Screenshot::Saver do
  it "keeps Capybara.save_path set while saving a failure dump" do
    saver = described_class.new(Capybara, Capybara.current_session)
    seen = :not_called

    saver.send(:clear_save_path) { seen = Capybara.save_path }

    expect(seen).to eq(Capybara.save_path)
    expect(seen).to be_present
  end
end
