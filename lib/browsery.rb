require 'bundler/setup'

envs = [:default]

Bundler.setup(*envs)
require 'minitest'
require 'yaml'
require 'erb'
require 'faker'
require 'selenium/webdriver'
require 'rest-client'
require 'json'
require 'cgi'
require 'pathname'
require 'active_support/logger'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/string/starts_ends_with'
require 'active_support/core_ext/string/strip'
require 'active_support/core_ext/hash'

require_relative 'minitap/minitest5_browsery'
require_relative 'selenium/webdriver/common/element_browsery'

require_relative 'browsery/init'
