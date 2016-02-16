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

require_relative 'minitap/minitest5_browsery'
require_relative 'selenium/webdriver/common/element_browsery'

Time::DATE_FORMATS[:month_day_year] = "%m/%d/%Y"

require_relative 'browsery/init'
