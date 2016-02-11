lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'browsery/version'

Gem::Specification.new do |s|
  s.name          = "browsery"
  s.version       = Browsery::VERSION
  s.authors       = ["Peijie Hu"]

  s.summary       = %q{Browsery}
  s.description   = %q{Browsery}
  s.homepage      = "https://github.com/peijiehu/browsery"
  s.license       = "MIT"

  s.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  s.bindir        = "bin"
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_development_dependency 'rake'
  s.add_development_dependency 'yard'
end
