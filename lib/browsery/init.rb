# The base module for everything Browsery and is the container for other
# modules and classes in the hierarchy:
#
# * `Connector` provides support for drivers and connector profiles;
# * `PageObjects` provides a hierarchy of page objects, page modules, widgets,
#   and overlays;
# * `Settings` provides support for internal Browsery settings; and
# * `Utils` provides an overarching module for miscellaneous helper modules.
module Browsery

  def self.logger
    @@logger ||= Browsery::Logger.new($stdout)
  end

  def self.logger=(value)
    @@logger = value
  end

  def self.settings
    @@settings ||= Settings.new
  end

  def self.settings=(options)
    self.settings.merge!(options)
  end

  # Root directory of the automation repository.
  # Automation repo can use it to refer to files within itself,
  # and this gem also uses it to refer to config files of automation,
  # for example:
  #
  #   File.read(Browsery.root.join('config/browsery', 'data.yml'))
  #
  # will return the contents of `automation_root/config/browsery/data.yml`.
  #
  # @return [Pathname] A reference to the root directory, ready to be used
  #         in directory and file path calculations.
  def self.root
    @@__root__ ||= Pathname.new(File.expand_path('.'))
  end

  # Absolute path of root directory of this gem
  # can be used both within this gem and in automation repo
  def self.gem_root
    @@__gem_root__ ||= Pathname.new(File.realpath(File.join(File.dirname(__FILE__), '..', '..')))
  end

end

require_relative 'runner'
require_relative 'logger'
require_relative 'utils'

require_relative 'connector'
require_relative 'page_objects'
require_relative 'parallel'
require_relative 'settings'

require_relative 'test_case'
require_relative 'console'
