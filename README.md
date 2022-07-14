# dafny-reportgenerator
A tool for analyzing and reporting on Dafny, especially the results of verification.

The primary use of this tool (for now) is to flag more expensive verification tasks, as these are
more likely to a source of future *verification instability*: the phenomenon where code that was previously verified
no longer verifies after making seemingly unrelated changes. This problem can make consistent and predictable development
of Dafny code challenging, and hence we recommend adding a command to invoke this tool with a configured maximum
verification cost to any Dafny project's continuous integration. This is better than setting a more aggressive verification
cost bound through options like `/timeLimit` directly, as it allows users to know that their code is still correct, 
but still blocks code changes that are too expensive to verify and hence likely to break in the future. 
Note that this tool, which is itself implemented in Dafny, is [no exception](.github/workflows/build-and-test.yml)!

There are currently two different metrics that you can set a maximum bound on:

1. `--max-duration-seconds N`

   Bounds the wall-clock time needed to complete a verification task. This is obviously intuitive for users,
   but will vary across different computing resources, especially how many verification tasks are running in parallel.

2. `--max-resource-count N` (Recommended)

   Bounds the number of "resources" needed to complete a verification task. The resource count is an abstract measurement of
   verification cost that depends only on the input formula and exact SMT solver configuration, and hence will be the same
   across multiple verification jobs. Some SMT solvers (e.g. Z3) allow configuring a direct limit on this metric through
   an `:rlimit` parameter, although the SMT-LIB standard introduces a similar `:reproducible-resource-limit` parameter 
   as of version 2.5 (https://smtlib.cs.uiowa.edu/papers/smt-lib-reference-v2.5-r2015-06-28.pdf, page 54).

3. `--max-duration-stddev N`

    Bounds the standard deviation of multiple measurements of the
    wall-clock time needed to complete a verification task. This option
    is especially useful for measuring the stability of verification
    when varying the `/randomSeed` parameter to Dafny. The output will
    only be meaningful if the collection of CSV files being analyzed
    includes results from more than one Dafny run. This will be true if
    you've run Dafny more than once on the same set of input files with
    without explicitly specifying a CSV output file name and without
    deleting the `TestResults` directory or any of its contents between
    runs.

4. `--max-resource-stddev N`

    Bounds the standard deviation of multiple measurements of the
    solver "resources" needed to complete a verification task. This is
    similar to `--max-duration-stddev` but more stable between different
    runs and across different platforms.

5. `--allow-different-outcomes`

    Don't fail if a given verification task has more than one type of
    outcome (e.g., success and timeout). Normally, this is considered an
    error, but during the process of making a project more stable it can
    sometimes be useful to allow.

Here is an example of the output of this tool when run against the results of verifying itself. The CSV files
were created by passing `/verificationLogger:csv` when invoking the `dafny` command-line tool. The maximum resource count
is set unrealistically low here, just to demonstrate the behavior when violated.

```
> dafny-reportgenerator summarize-csv-results --max-resource-count 500000 .
All results: 

Impl$$Main.__default.ParseCommandLineOptions(Passed) - Duration = 00:00:00.1940000, Resource Count = 581969
Impl$$Main.__default.MainAux(Passed) - Duration = 00:00:00.2470000, Resource Count = 356337
CheckWellformed$$StandardLibrary.__default.MergeSortedBy(Passed) - Duration = 00:00:00.1570000, Resource Count = 333138
Impl$$TestResult.__default.ParseTestResults(Passed) - Duration = 00:00:00.2070000, Resource Count = 318950
CheckWellformed$$CSV.__default.ParseDataWithHeader(Passed) - Duration = 00:00:00.9010000, Resource Count = 265695
CheckWellformed$$TestResult.__default.ParseFromCSVRow(Passed) - Duration = 00:00:00.1430000, Resource Count = 202603
CheckWellformed$$CSV.__default.ParseRowWithHeader(Passed) - Duration = 00:00:00.1200000, Resource Count = 194334
Impl$$CSVTests.__default.ParseDataWithHeader(Passed) - Duration = 00:00:01.1220000, Resource Count = 182160
CheckWellformed$$StandardLibrary.__default.MergeSortBy(Passed) - Duration = 00:00:00.0950000, Resource Count = 168961
CheckWellformed$$TestResult.__default.GetCSVRowField(Passed) - Duration = 00:00:00.0940000, Resource Count = 116280
Impl$$StandardLibrary.__default.LemmaNewFirstElementStillSortedBy(Passed) - Duration = 00:00:00.0820000, Resource Count = 112567
CheckWellformed$$StandardLibrary.__default.Split(Passed) - Duration = 00:00:00.4470000, Resource Count = 99661
CheckWellformed$$CSV.__default.ParseRow(Passed) - Duration = 00:00:00.0800000, Resource Count = 92111
CheckWellformed$$StandardLibrary.__default.LemmaNewFirstElementStillSortedBy(Passed) - Duration = 00:00:00.0720000, Resource Count = 89524
CheckWellformed$$StandardLibrary.__default.SortedBy(Passed) - Duration = 00:00:00.0710000, Resource Count = 87462
CheckWellformed$$TestResult.TestResult.ToString(Passed) - Duration = 00:00:00.4490000, Resource Count = 83944
Impl$$Main.__default._default_Main(Passed) - Duration = 00:00:00.6980000, Resource Count = 82411
Impl$$Main.__default.PrintTestResults(Passed) - Duration = 00:00:00.0520000, Resource Count = 66537

Some results have a resource count over the configured limit of 500000:

Impl$$Main.__default.ParseCommandLineOptions(Passed) - Duration = 00:00:00.1940000, Resource Count = 581969

Errors occurred: see above for details.
```
