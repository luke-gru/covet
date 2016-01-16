require File.expand_path('../lib/covet/version', __FILE__)

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'covet'
  s.version     = Covet::VERSION
  s.summary     = 'Regression test selection tool based on coverage information'
  s.description = 'Uses git and ruby coverage information to determine which tests to run from your test suite'
  s.homepage = "https://github.com/luke-gru/covet"

  s.required_ruby_version = '>= 1.9.1'

  s.license = 'MIT'

  # The idea and some code is taken directly from Aaron Patterson.
  # See http://tenderlovemaking.com/2015/02/13/predicting-test-failues.html
  # for more info.
  s.authors   = ['Luke Gruber']
  s.email    = 'luke.gru@gmail.com'

  s.bindir = 'bin'
  s.require_paths = ['lib']
  s.executables = ['covet']
  s.files = Dir[
    'lib/**/*.rb',
    'ext/**/*.{c,rb}',
    'bin/*',
    'test/**/*.rb',
    'spec/**/*.rb',
    'README.md',
    'Rakefile',
    'Gemfile',
    'gemfiles/*.gemfile',
    '.travis.yml',
    '.gitignore',
  ]
  s.test_files = Dir[
    'test/**/*.rb',
    'spec/**/*.rb',
  ]
  s.extensions = ['ext/covet_coverage/extconf.rb']

  s.add_dependency 'rugged' # TODO: remove from here and autodetect later when more VCSs are supported
  s.add_development_dependency 'rake-compiler'
  s.add_development_dependency 'wwtd'
  s.add_development_dependency 'bundler'
end
