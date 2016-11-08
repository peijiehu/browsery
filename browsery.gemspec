lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'browsery/version'

Gem::Specification.new do |s|
  s.name          = "browsery"
  s.version       = Browsery::VERSION
  s.authors       = ["Peijie Hu"]

  s.summary       = %q{Browser automation test framework}
  s.description   = %q{Browsery is a browser automation test framework}
  s.homepage      = "https://github.com/peijiehu/browsery"
  s.license       = "MIT"

  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir        = "bin"
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency 'activesupport', '~> 4.2'
  s.add_dependency 'faker', '~> 1.4'
  s.add_dependency 'minitap', '~> 0.5.3'
  s.add_dependency 'pry', '~> 0.10'
  s.add_dependency 'minitest', '~>5.4.0'
  s.add_dependency 'selenium-webdriver', '~> 3.0'
  s.add_dependency 'rest-client', '~> 1.8'
  s.add_dependency 'chunky_png', '~> 1.3'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'yard'
end
