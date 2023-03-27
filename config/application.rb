require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module RailsEventSourcing
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"

    # Load extra Paths
    config.paths.add 'packages/ordering', glob: '{app/*,app/*/concerns,lib}', eager_load: true
    config.paths.add 'packages/invoicing', glob: '{app/*,app/*/concerns,lib}', eager_load: true

    # Set null_session for default protect_from_forgery
    config.action_controller.default_protect_from_forgery = false
  end
end
