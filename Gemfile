source 'https://rubygems.org'
gemspec

group :test, :development do
  gem 'rspec'
  gem 'minitest'
end

group :test, :development do
  if RUBY_VERSION.to_i < 2
    gem 'debugger'
  else
    gem 'byebug'
  end
end
