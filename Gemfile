source 'https://rubygems.org'
gemspec

group :test, :development do
  gem 'rspec'
  gem 'minitest'
  if ENV['COVET_DEBUG']
    if RUBY_VERSION.to_i < 2
      gem 'debugger'
    else
      gem 'byebug'
    end
  end
end
