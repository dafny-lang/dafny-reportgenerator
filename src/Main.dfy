
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/BoundedInts.dfy"
include "../libraries/src/Collections/Sequences/Seq.dfy"

include "CSV.dfy"
include "Externs.dfy"
include "StandardLibrary.dfy"
include "TestResult.dfy"

module Main {

  import opened Wrappers
  import opened Seq

  import CSV
  import Externs
  import StandardLibrary
  import opened TestResult
  
  method Main() {
    // Working around the lack of arguments or return value on main methods.
    // See https://github.com/dafny-lang/dafny/issues/1116.
    var args := Externs.GetCommandLineArgs();
    var result := MainAux(args);
    if result.IsFailure() {
      print result.error, "\n";
      Externs.SetExitCode(1);
    } else {
      Externs.SetExitCode(0);
    }
  }

  datatype Options = Options(justHelpText: bool := false,
                             maxDurationSeconds: Option<nat> := None, 
                             maxResourceCount: Option<nat> := None,
                             maxDurationStddev: Option<real> := None,
                             maxDurationCV: Option<real> := None,
                             maxResourceStddev: Option<real> := None,
                             maxResourceCV: Option<real> := None,
                             allowDifferentOutcomes: bool := false,
                             filePaths: seq<string> := [])

  // TODO: It would be nice to return an `Outcome<string>` instead, but the current
  // behavior of the `:-` elephant operator doesn't currently work that way.
  // See https://github.com/dafny-lang/dafny/issues/1893.  
  method MainAux(args: seq<string>) returns (result: Result<(), string>) {
    var options :- ParseCommandLineOptions(args);
    if options.justHelpText {
      return Success(());
    }
    
    // Here I really wish I could use MapWithResult on a method-based Action instead of just a function :(
    // See also https://github.com/dafny-lang/libraries/pull/29.
    var allResults := [];
    for pathIndex := 0 to |options.filePaths| {
      // Find all **/TestResults/*.csv files if the given path is a directory.
      // I would have liked to make the result a `set<string>` here instead of a `seq<string>`,
      // to indicate that the ordering is not significant, but sets are currently difficult and
      // expensive to traverse in pure Dafny. See https://github.com/dafny-lang/dafny/issues/424.
      var matchingFiles :- Externs.FindAllCSVTestResultFiles(options.filePaths[pathIndex]);
      for fileIndex := 0 to |matchingFiles| {
        var resultsBatch :- ParseTestResults(matchingFiles[fileIndex]);
        allResults := allResults + resultsBatch;
      }
    }

    // Sort by the negative resource count in order to sort from highest to lowest
    var negativeResourceCountGetter: TestResult.TestResult -> int := (r: TestResult.TestResult) => -(r.resourceCount as int);
    var allResultsSorted := StandardLibrary.MergeSortBy(allResults, negativeResourceCountGetter);

    // Group the results by name, for aggregate statistics
    var groupedResults := GroupTestResults(allResultsSorted);
    var groupedResultConsistency := ResultGroupConsistency(groupedResults);
    var inconsistentResults := Filter((r: (string, bool)) => !r.1, groupedResultConsistency);

    if || options.maxResourceStddev.Some?
       || options.maxResourceCV.Some?
       || options.maxDurationStddev.Some?
       || options.maxDurationCV.Some? {
      print "All results (statistics):\n\n";
      PrintAllTestResultStatistics(groupedResults);
    } else {
      print "All results: \n\n";
      PrintTestResults(allResultsSorted);
    }

    var passed := true;

    if options.maxDurationSeconds.Some? {
      var maxDurationTicks :=  options.maxDurationSeconds.value as int * Externs.DurationTicksPerSecond;
      var allResultsOverLimit := Filter((r: TestResult.TestResult) => maxDurationTicks < r.durationTicks as int, allResultsSorted);
      if 0 < |allResultsOverLimit| {
        passed := false;
        print "\nSome results have a duration over the configured limit of ", options.maxDurationSeconds.value, " second(s):\n\n";
        PrintTestResults(allResultsOverLimit);
      }
    }

    if options.maxResourceCount.Some? {
      // First check for any results with a resource count of "0".
      // At the time of writing this, Dafny will report 0 for any methods with splits, and
      // we don't want to spuriously pass this check because of it.
      var allResultsWithZeroResourceCounts := Filter((r: TestResult.TestResult) => r.resourceCount == 0, allResultsSorted);
      if 0 < |allResultsWithZeroResourceCounts| {
        passed := false;
        print "\nSome results have a resource count of zero:\n\n";
        PrintTestResults(allResultsWithZeroResourceCounts);
      }

      var allResultsOverLimit := Filter((r: TestResult.TestResult) => options.maxResourceCount.value < r.resourceCount, allResultsSorted);
      if 0 < |allResultsOverLimit| {
        passed := false;
        print "\nSome results have a resource count over the configured limit of ", options.maxResourceCount.value, ":\n\n";
        PrintTestResults(allResultsOverLimit);
      }
    }

    passed := PrintStatistics(options, groupedResults, passed);

    if |inconsistentResults| > 0 && !options.allowDifferentOutcomes {
      print "\nThe following results have inconsistent outcomes:\n\n";
      for i := 0 to |inconsistentResults| {
        print "  ", inconsistentResults[i].0, "\n";
      }
      passed := false;
    }

    :- Need(passed, "\nErrors occurred: see above for details.\n");

    return Success(());
  }

  method PrintStatistics(options: Options, groupedResults: map<string, seq<TestResult.TestResult>>, initialPassed: bool)
    returns (passed: bool)
  {
    passed := initialPassed;
    if options.maxDurationStddev.Some? {
      var stddevs := ResultGroupStatistics(groupedResults, results => TestResultDurationStatistics(results).stddev);
      passed := PrintExceedingValues("duration standard deviation", stddevs, options.maxDurationStddev.value);
    }

    if options.maxDurationCV.Some? {
      var CVs := ResultGroupStatistics(groupedResults, results => TestResultDurationStatistics(results).CV());
      passed := PrintExceedingValues("duration CV", CVs, options.maxDurationCV.value);
    }

    if options.maxResourceStddev.Some? {
      var stddevs := ResultGroupStatistics(groupedResults, results => TestResultResourceStatistics(results).stddev);
      passed := PrintExceedingValues("resource standard deviation", stddevs, options.maxResourceStddev.value);
    }

    if options.maxResourceCV.Some? {
      var CVs := ResultGroupStatistics(groupedResults, results => TestResultResourceStatistics(results).CV());
      passed := PrintExceedingValues("resource CV", CVs, options.maxResourceCV.value);
    }
  }

  method PrintExceedingValues(description: string, values: seq<(string, real)>, limit: real) returns (passed: bool) {
      var exceedingValues := Filter((t:(string, real)) => limit < t.1, values);
      if 0 < |exceedingValues| {
        passed := false;
        print "\nSome results have a ", description, " over the configured limit of ", limit, ":\n\n";
        for resIdx := 0 to |exceedingValues| {
          var t : (string, real) := exceedingValues[resIdx];
          print t.0, ": ", description, " = ", Externs.RealToString(t.1), "\n";
        }
      } else {
        passed := true;
      }
  }

  method PrintTestResults(results: seq<TestResult.TestResult>) {
    for i := 0 to |results| {
      print results[i].ToString(), "\n";
    }
  }

  const helpText :=
      "usage: dafny-reportgenerator summarize-csv-results [--max-resource-count N]\n" +
      "                                                   [--max-duration-seconds N]\n" +
      "                                                   [--max-resource-stddev N]\n" +
      "                                                   [--max-resource-cv N]\n" +
      "                                                   [--max-duration-stddev N]\n" +
      "                                                   [--max-duration-cv N]\n" +
      "                                                   [file_paths ...]\n" +
      "\n" +
      "file_paths                 CSV files produced from Dafny's /verificationLogger:csv feature.\n" +
      "                           Directory paths are also accepted, in which case all CSV files under all\n" +
      "                           \"TestResults\" descendant directories are included.\n" +
      "--max-resource-count N     Fail if any results have a resource count over the given value.\n" +
      "--max-duration-seconds N   Fail if any results have a duration over the given value in seconds.\n" +
      "--max-resource-stddev N    Fail if multiple results exist for each proof obligation and the standard\n" +
      "                           deviation of their resource counts is over the given value.\n" +
      "--max-resource-cv N        Fail if multiple results exist for each proof obligation and the coefficient\n" +
      "                           of variance (stddev / mean) of their resource counts is over the given\n" +
      "                           value (stated as an integer percentage).\n" +
      "--max-duration-stddev N    Fail if multiple results exist for each proof obligation and the standard\n" +
      "                           deviation of their durations is over the given value.\n" +
      "--max-duration-cv N        Fail if multiple results exist for each proof obligation and the coefficient\n" +
      "                           of variance (stddev / mean) of their durations is over the given value (stated\n" +
      "                           as an integer percentage).\n" +
      "";

  method ParseCommandLineNat(args: seq<string>, argIndex: nat)
    returns (result: Result<nat, string>)
    requires argIndex < |args|
  {
    :- Need(argIndex + 1 < |args|, args[argIndex] + " must be followed by an argument\n\n" + helpText);
    var val :- Externs.ParseNat(args[argIndex + 1]);
    return Success(val);
  }

  method ParseCommandLineOptions(args: seq<string>) returns (result: Result<Options, string>) {
    :- Need(|args| >= 2, "Not enough arguments.");

    if args[1] == "--help" {
      print helpText;
      return Success(Options(justHelpText := true));
    }

    // For now only one top-level command
    :- Need(args[1] == "summarize-csv-results", "The only supported command is `summarize-csv-results`");

    var maxResourceCount: Option<nat> := None;
    var maxDurationSeconds: Option<nat> := None;
    var maxResourceStddev: Option<real> := None;
    var maxResourceCV: Option<real> := None;
    var maxDurationStddev: Option<real> := None;
    var maxDurationCV: Option<real> := None;
    var allowDifferentOutcomes: bool := false;
    var filePaths: seq<string> := [];
    var argIndex := 2;
    while argIndex < |args| {
      var arg := args[argIndex];
      match arg {
        case "--max-resource-count" => {
          var count :- ParseCommandLineNat(args, argIndex);
          argIndex := argIndex + 1;
          maxResourceCount := Some(count);
        }
        case "--max-duration-seconds" => {
          var seconds :- ParseCommandLineNat(args, argIndex);
          argIndex := argIndex + 1;
          maxDurationSeconds := Some(seconds);
        }
        case "--max-resource-stddev" => {
          var count :- ParseCommandLineNat(args, argIndex);
          argIndex := argIndex + 1;
          maxResourceStddev := Some(count as real);
        }
        case "--max-resource-cv" => {
          var pct :- ParseCommandLineNat(args, argIndex);
          argIndex := argIndex + 1;
          maxResourceCV := Some(pct as real / 100.0);
        }
        case "--max-duration-stddev" => {
          var seconds :- ParseCommandLineNat(args, argIndex);
          argIndex := argIndex + 1;
          maxDurationStddev := Some((seconds * Externs.DurationTicksPerSecond) as real);
        }
        case "--max-duration-cv" => {
          var pct :- ParseCommandLineNat(args, argIndex);
          argIndex := argIndex + 1;
          maxDurationCV := Some(pct as real / 100.0);
        }
        case "--allow-different-outcomes" => {
          allowDifferentOutcomes := true;
        }
        case _ => {
          filePaths := filePaths + [arg];
        }
      }
      argIndex := argIndex + 1;
    }
    return Success(Options(maxDurationSeconds := maxDurationSeconds,
                           maxResourceCount := maxResourceCount,
                           maxResourceStddev := maxResourceStddev,
                           maxResourceCV := maxResourceCV,
                           maxDurationStddev := maxDurationStddev,
                           maxDurationCV := maxDurationCV,
                           allowDifferentOutcomes := allowDifferentOutcomes,
                           filePaths := filePaths));
  }
}
