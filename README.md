Covet
=====

What Is It?
-----------

It's a regression test selection tool for ruby, an implementation
of some ideas by Mr. Tenderlove expressed
[here](http://tenderlovemaking.com/2015/02/13/predicting-test-failues.html).
Basically, it shortens your test suite time by only running tests for files that you changed.

How Does It Work?
-----------------

Reading the article will give you a good idea, but here's a short summary:

1) Covet gathers coverage information during your test suite runs, before and after
each test method in order to know which test methods ran which files and lines of the tested
application code.

2) You then change the application code and/or the test code itself.

3) Covet shows you which tests to run based on the coverage information
gathered in step 1, and the fact that `git` knows that you changed
certain lines of the application code. It outputs which files to run, and
you can also use it to execute those files, or have it return those files to you
in JSON.

Usage
-----

Add `covet` to your Gemfile in your test or development `:group`, or:

    $ gem install covet

Coverage Collection:

Run your test suite with coverage collection on. To enable this,
add `require 'covet'` before any tests run (in a test helper file or similar),
and run your suite with: `covet -c $CMD`, where $CMD is the command to run your
test suite. Example:

    $ covet -c "rake test"

Covet should output a message before any tests run:

    Collecting coverage information for each test method...

By default, `covet` hooks into `minitest` and collects coverage before
and after each method. If you're using `rspec`, make sure to pass the `-t`
option:

    $ covet -t rspec -c "rake test"

After this, you should have 2 new files: `run_log.json`, and
`run_log_index.json`.

Now, by default the `covet` command will print out which test
files should be run based off the changes in your git repo since
the last commit.

For example:

    $ covet

    You need to run:
    - /home/luke/Desktop/code/rails/activesupport/test/array_inquirer_test.rb

To execute the run list, simply:

    $ covet -e

    ruby -I"test" -I"lib" -I"/home/luke/.rvm/rubies/ruby-2.2.2/lib/ruby/2.2.0" "/home/luke/.rvm/rubies/ruby-2.2.2/lib/ruby/2.2.0/rake/rake_test_loader.rb" "/home/luke/Desktop/code/rails/activesupport/test/array_inquirer_test.rb" "-n /test_any_string_symbol_mismatch|test_individual|test_any|test_any_with_block/"
    Run options: "-n /test_any_string_symbol_mismatch|test_individual|test_any|test_any_with_block/" --seed 63509

    # Running:

    ....

    Finished in 0.001748s, 2287.6961 runs/s, 5719.2402 assertions/s.

    4 runs, 10 assertions, 0 failures, 0 errors, 0 skips

As you can see, by default covet will also only run the test methods that ran
the code that you modified. You can disable this option, and have it run the
files as a whole if any of the test methods in that file exercised any
changed library/application code by using the `--disable-method-filter`
option. See the 'Options' section for a more detailed reference.

Testing Gems
------------

By default, `covet` removes all standard library and gem files from the `run_log`, because
it assumes you're testing your own library/application code. In order to test a gem, you need to add the
`--whitelist-gems` option. For example:

    $ covet -c "rake test" --whitelist-gems "activesupport,rails"

Limitations
-----------

1) If you change any application/library code that is run before any of your test
cases run, `covet` has to be conservative and tell you to run your entire test
suite again. You will know when this happens, as you'll receive the following
message:


    $ covet
    You need to run every test file due to change(s) to line(s) that run on application load.
    $ covet -e # this will just run your whole test suite again

However, if you know your changes won't cause any tests to fail, you can work
around this issue by supplying the `--ignore-changed-files` option. See the
'Options' section for more info.

Options/Flags
-------------

All flags are optional. By default (no flags given), covet will print out the list of test
files to run based on the last coverage collection and the files changed since the most recent commit
on the current branch.

    --help (-h)                   Prints help and exits

    --version (-v)                Prints version and exits

    --collect (-c) CMDLINE        Command-line to use for coverage collection phase. No default, must be specified.
                                  Example: covet -c 'bundle exec rake test'

    --whitelist-gems GEMS         Whitelist given gems during collection phase. By default, all gems are blacklisted and
                                  therefore the collection phase ignores changes to any gem code.
                                  Example: covet -c 'rake test:all' --whitelist-gems 'activesupport,activemodel'

    --print-fmt FMT               When printing run list, specifies a format. By default, covet prints out a list of test
                                  files to run. This is the 'list' format. You can also specify the 'test-runner' format,
                                  which prints the command-line that "covet -e" would run. The 'json' format will output
                                  the list of test files to run in JSON.

    --exec (-e)                   Executes the run list using rake's test loader. If there are no test files to run, outputs
                                  '# No test cases to run'

    --ignore-changed-files FILES  Files or globs to ignore when generating the run list (list of test files to run) for printing
                                  or execution.
                                  Example: covet --ignore-changed-files 'lib/algo.rb,lib/algo/**/*'

    --disable-method-filter       When executing the run list (covet --exec), run full test files (all the test cases in each file)
                                  instead of filtering and running only the ones that exercised changed application/library code.

    --revision REVISION (-r)      Specify the git revision (commit hash) to use as the baseline for seeing which lines have changed.
                                  This is used in conjunction with printing or executing the run list. If not specified, covet will use
                                  the last commit in the current branch as the baseline.

    --test-runner RUNNER (-t)     Specify which test runner to hook into when running the coverage collection phase (covet -c). By default,
                                  uses `minitest`. Can also use `rspec`.


