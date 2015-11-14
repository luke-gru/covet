Covet (alpha)
=============

What Is It?
-----------

It's a regression test selection tool for ruby, an implementation
of some ideas by Mr. Tenderlove expressed
[here](http://tenderlovemaking.com/2015/02/13/predicting-test-failues.html).

How Does It Work?
-----------------

Reading the article will give you a good idea, but here's a short summary:

1) Gather coverage information during test runs, before and after
each test method in order to know which test methods ran which
files and lines of the tested application code.

2) Change the application code.

3) Covet shows you which tests to run based on the coverage information
gathered in step 1, and the fact that `git` knows that you changed
certain lines of the application code.

Usage
-----

Coverage Collection:

Run your test suite with coverage collection on. There are many ways
to enable this, the easiest probably being to `require 'covet'` before
any tests run (in a test helper file or similar), and run your suite with:
`covet -c $CMD`, where $CMD is the command to run your test suite. Example:

    $ covet -c rake

Covet should output a message before any other message:

    Collecting coverage information for each test method...

By default, `covet` hooks into `minitest` and collects coverage before
and after each method. If you're using `rspec`, make sure to pass the `-t`
option:

    $ covet -t rspec -c rake

After this, you should have 2 new files: `run_log.json`, and
`run_log_index.json`.

Now, by default the `covet` command will print out which test
files should be run based off the changes in your git repo since
the last commit.

For example:

    $ covet


Caveats/Bugs
------------

1) It's not tested thoroughly enough.

2) Don't rely on this yet, it's still early days. Please contribute code,
docs, or ideas, though!
