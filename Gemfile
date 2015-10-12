source 'https://rubygems.org'
gem 'rugged'
group :development do
  gem 'rake-compiler'
end
group :test, :development do
  gem 'minitest'
  gem 'rspec'
end
group :development do
  if RUBY_VERSION >= "2.0.0"
    gem 'byebug'
  else
    gem 'debugger'
  end
end
