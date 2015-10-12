# NOTE: Do not require this file from outside of a commandline.
#
# Require this file from a commandline directly like this:
#
#     $ ruby -I"test" -r"covet_collect" my_test1.rb my_test2.rb
#
# This will run these tests and collect their coverage information in a run
# log file.
#
# Alternatively, use the `covet` command directly:
#     $ covet -c 'ruby -I"test" my_test1.rb my_test2.rb'
#
# Use the first commandline format if possible, and the second only when you can't
# require a ruby file with a certain command, like with `rake` (1), or if you need
# to pass options to `covet` (2), like if you're using `rspec` instead of
# `minitest`:
#
#     1) $ covet -c "rake"
# You can't run '$ rake -r"covet_collect"', rake doesn't have the -r option.
#
#     2) $ covet -t "rspec" -c "rake"
#
require_relative 'covet'
Covet.register_coverage_collection!
