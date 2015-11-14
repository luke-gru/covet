require File.expand_path('../lib/covet/version', __FILE__)

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'covet'
  s.version     = Covet::VERSION
  s.summary     = 'Regression test selection tool based on coverage information'
  s.description = 'Uses git and ruby coverage information to determine which tests to run from your test suite'

  s.required_ruby_version = '>= 1.9.1'

  s.license = 'MIT'

  s.authors   = ['Luke Gruber'] # idea and some code taken directly from Aaron Patterson
  s.email    = 'luke.gru@gmail.com'

  s.bindir = 'bin'
  s.require_paths = ['lib']
  s.executables = ['covet']
  s.files = Dir[
    'lib/**/*.rb',
    'ext/**/*.{c,rb}',
    'Rakefile',
    'Gemfile',
    'README.md',
  ]
  s.extensions = ['ext/covet_coverage/extconf.rb']

  s.add_dependency 'rugged' # TODO: remove from here and autodetect later when more VCSs are supported
  s.add_development_dependency 'rake-compiler'
end
