module Browsery

  # An object that holds runtime settings.
  #
  # Furthermore, Minitest doesn't provide any good way of passing a hash of
  # options to each test.
  #
  # TODO: We're importing ActiveSupport's extensions to Hash, which means that
  # we'll be amending the way Hash objects work; once AS updates themselves to
  # ruby 2.0 refinements, let's move towards that.
  class Settings

    def initialize
      @hsh = {}
    end

    def inspect
      settings = self.class.public_instance_methods(false).sort.map(&:inspect).join(', ')
      "#<Browsery::Settings #{settings}>"
    end

    def auto_finalize?
      hsh.fetch(:auto_finalize, true)
    end

    def connector
      hsh.fetch(:connector, :firefox).to_s
    end

    def env
      # add a gitignored env file which stores a default env
      # pass the default env in as default
      hsh.fetch(:env, :rent_qa).to_s
    end

    def sauce_session_http_auth(driver)
      session_id = driver.session_id
      "https://#{sauce_username}:#{sauce_access_key}@saucelabs.com/rest/v1/#{sauce_username}/jobs/#{session_id}"
    end

    def sauce_username
      sauce_user["user"]
    end

    def sauce_access_key
      sauce_user["pass"]
    end

    def io
      hsh[:io]
    end

    def merge!(other)
      hsh.merge!(other.symbolize_keys)
      self
    end

    # can be used as a flag no matter parallel option is used in command line or not
    # can also be used to fetch the value if a valid value is specified
    def parallel
      if hsh[:parallel] == 0
        return nil
      else
        hsh.fetch(:parallel).to_i
      end
    end

    def raw_arguments
      hsh.fetch(:args, nil).to_s
    end

    def reuse_driver?
      hsh.fetch(:reuse_driver, false)
    end

    def rerun_failure
      hsh.fetch(:rerun_failure)
    end

    def visual_regression
      hsh.fetch(:visual_regression)
    end

    def seed
      hsh.fetch(:seed, nil).to_i
    end

    def tags
      hsh[:tags] ||= []
    end

    def verbose?
      verbosity_level > 0
    end

    def verbosity_level
      hsh.fetch(:verbosity_level, 0).to_i
    end

    private
    attr_reader :hsh

    def sauce_user
      overrides = connector.split(/:/)
      file_name = overrides.shift
      path = Browsery.root.join('config/browsery', 'connectors')
      filepath  = path.join("#{file_name}.yml")
      raise ArgumentError, "Cannot load profile #{file_name.inspect} because #{filepath.inspect} does not exist" unless filepath.exist?

      cfg = YAML.load(File.read(filepath))
      cfg = Connector.resolve(cfg, overrides)
      cfg.freeze
      cfg["hub"]
    end

  end

end
