Covet (alpha)
=============

What Is It?
-----------

It's a regression test selection tool for ruby, an implementation
of some ideas by Mr. Tenderlove expressed
[here](http://tenderlovemaking.com/2015/02/13/predicting-test-failues.html)

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

Caveats/Bugs
------------

1) It's slow - Collecting the coverage information and logging it currently
takes too long for certain test suites. For instance, I tested `covet` on
`activesupport`'s test suite, and it still takes longer than I think
is necessary. The problem is that the logs are not compressed enough, and
contain lots of redundant information, but it's hard to figure out exactly
how to mitigate this without forcing users to run their test suites in the
same order each time, which is not ideal. Ideas are more than welcome!

2) It's not tested thoroughly enough.

3) Don't rely on this yet, it's still early days. Please contribute code,
docs, or ideas, though!
