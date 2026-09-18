# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara-screenshot/rspec'
require 'capybara/email/rspec'

Capybara.default_max_wait_time = 6

# Parallel test processes must not share the downloads/screenshots directory:
# DownloadHelpers reads "the first zip in save_path", which could come from
# another process. Serial runs keep the default tmp/capybara.
Capybara.save_path = Rails.root.join("tmp/capybara#{ENV['TEST_ENV_NUMBER']}")

Capybara.ignore_hidden_elements = false

Capybara.enable_aria_label = true

Capybara.disable_animation = true

# Save a snapshot of the HTML page when an integration test fails
Capybara::Screenshot.autosave_on_failure = true
# Keep only the screenshots generated from the last failing test suite
Capybara::Screenshot.prune_strategy = :keep_last_run
# Tell Capybara::Screenshot how to take screenshots when using the playwright driver
Capybara::Screenshot.register_driver :playwright do |driver, path|
  driver.save_screenshot(path)
end

# capybara-screenshot sets `Capybara.save_path` to nil while it writes the
# failure dump, a workaround for Capybara 1 prepending save_path to the absolute
# paths it passes. Capybara 3 ignores save_path for an absolute path, so the
# workaround is a no-op — except that capybara-playwright-driver reads
# `Capybara.save_path` in its `download` handler, on the Playwright transport
# thread. A download landing during the dump raises `mkdir_p(nil)` there, the
# transport thread dies, and every later Playwright call blocks until the CI
# job times out. Keep save_path set for the whole dump.
module Capybara::Screenshot::KeepSavePath
  private

  def clear_save_path
    yield
  end
end
Capybara::Screenshot::Saver.prepend(Capybara::Screenshot::KeepSavePath)

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    options = {
      browser_type: (ENV['PLAYWRIGHT_BROWSER'] || 'chromium').to_sym, # :chromium (default) or :firefox, :webkit
      headless: ENV['NO_HEADLESS'].blank?,
      locale: Rails.application.config.i18n.default_locale,
      downloadsPath: Capybara.save_path,
      playwright_cli_executable_path: 'bun --bun playwright',
    }

    driven_by(:playwright, options:)

    if ENV['MAKE_IT_SLOW'].present?
      raise 'MAKE_IT_SLOW uses CDP and only works with the (default) chromium browser' if options[:browser_type] != :chromium

      Capybara.current_session.driver.with_playwright_page do |page|
        page.context.new_cdp_session(page).send_message(
          'Network.emulateNetworkConditions',
          params: {
            offline: false,
            latency: 800, # ms of added round-trip time
            downloadThroughput: 1_024_000,
            uploadThroughput: 1_024_000,
          }
        )
      end
    end

    if ENV['LOG_WEB_CONSOLE'].present?
      Capybara.current_session.driver.with_playwright_page do |page|
        page.on("console", -> (msg) { puts msg.text })
      end
    end
  end

  # Examples tagged with :capybara_ignore_server_errors will allow Capybara
  # to continue when an exception in raised by Rails.
  # This allows to test for error cases.
  config.around(:each, :capybara_ignore_server_errors) do |example|
    Capybara.raise_server_errors = false

    example.run
  ensure
    Capybara.raise_server_errors = true
  end
end

Capybara.add_selector(:by_label) do
  xpath do |text|
    # 1. Element has aria-label="text"
    has_aria_label = XPath.attr(:'aria-label').equals(text)

    # 2. Element's id is referenced by a <label for="...">
    label_for = XPath.anywhere(:label)[XPath.string.n.is(text)].attr(:for)
    has_label_for = XPath.attr(:id).equals(label_for)

    # 3. Element's aria-labelledby points to a label/element whose text matches
    # Find the id of any element whose text is our target text
    labelling_element_id = XPath.anywhere[XPath.string.n.is(text)].attr(:id)
    has_aria_labelledby = XPath.attr(:'aria-labelledby').equals(labelling_element_id)

    XPath.descendant[has_aria_label | has_label_for | has_aria_labelledby]
  end
end
