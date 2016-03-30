module Minitest

  # Minitest plugin: browsery_settings
  #
  # This is where the options are propagated to +Browsery.settings+.
  def self.plugin_browsery_settings_init(options)
    Browsery.settings = options

    Browsery.logger = Browsery::Logger.new('browsery.log', 'daily').tap do |logger|
      logger.formatter = proc do |sev, ts, prog, msg|
        msg = msg.inspect unless String === msg
        "#{ts.strftime('%Y-%m-%dT%H:%M:%S.%6N')} #{sev}: #{String === msg ? msg : msg.inspect}\n"
      end
      logger.level = case Browsery.settings.verbosity_level
                     when 0
                       Logger::WARN
                     when 1
                       Logger::INFO
                     else
                       Logger::DEBUG
                     end
      logger.info("Booting up with arguments: #{options[:args].inspect}")
      at_exit { logger.info("Shutting down") }
    end

    Browsery::Console.bootstrap! if options[:console]

    self
  end

  # Minitest plugin: browsery_settings
  #
  # This plugin for minitest injects browsery-specific command-line arguments, and
  # passes it along to browsery.
  def self.plugin_browsery_settings_options(parser, options)
    options[:auto_finalize] = true
    parser.on('-Q', '--no-auto-quit-driver', "Don't automatically quit the driver after a test case") do |value|
      options[:auto_finalize] = value
    end

    options[:connector] = ENV['BROWSERY_CONNECTOR'] if ENV.has_key?('BROWSERY_CONNECTOR')
    parser.on('-c', '--connector TYPE', 'Run using a specific connector profile') do |value|
      options[:connector] = value
    end

    options[:env] = ENV['BROWSERY_ENV'] if ENV.has_key?('BROWSERY_ENV')
    parser.on('-e', '--env ENV', 'Run against a specific environment, host_env') do |value|
      options[:env] = value
    end

    options[:console] = false
    parser.on('-i', '--console', 'Run an interactive session within the context of an empty test') do |value|
      options[:console] = true
    end

    options[:reuse_driver] = false
    parser.on('-r', '--reuse-driver', "Reuse driver between tests") do |value|
      options[:reuse_driver] = value
    end

    parser.on('-t', '--tag TAGLIST', 'Run only tests matching a specific tag, tags, or tagsets') do |value|
      options[:tags] ||= [ ]
      options[:tags] << value.to_s.split(',').map { |t| t.to_sym }
    end

    options[:verbosity_level] = 0
    parser.on('-v', '--verbose', 'Output verbose logs to the log file') do |value|
      options[:verbosity_level] += 1
    end

    options[:parallel] = 0
    parser.on('-P', '--parallel PARALLEL', 'Run any number of tests in parallel') do |value|
      options[:parallel] = value
    end

    options[:rerun_failure] = false
    parser.on('-R', '--rerun-failure [RERUN]', 'Rerun failing test; If enabled, can set number of times to rerun') do |value|
      integer_value = value.nil? ? 1 : value.to_i
      options[:rerun_failure] = integer_value
    end

    options[:visual_regression] = false
    parser.on('-V', '--visual-regression [TOLERANCE]', 'Enable visual regression,
    can optionally set tolerance level in percentage(0 tolerance by default),
    eg. -V 0.01 fails a test if visual difference is larger than 1%') do |value|
      float_value = value.nil? ? 0 : value.to_f
      options[:visual_regression] = float_value
    end
  end

end
