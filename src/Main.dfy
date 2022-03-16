
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
    
    print "All results: \n\n";
    PrintTestResults(allResultsSorted);

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

    :- Need(passed, "\nErrors occurred: see above for details.\n");

    return Success(());
  }

  method PrintTestResults(results: seq<TestResult.TestResult>) {
    for i := 0 to |results| {
      print results[i].ToString(), "\n";
    }
  }

  const helpText :=
      "usage: dafny-reportgenerator summarize-csv-results [--max-resource-count N] [--max-duration-seconds N] [file_paths ...]\n" +
      "\n" +
      "file_paths                 CSV files produced from Dafny's /verificationLogger:csv feature\n" +
      "--max-resource-count N     Fail if any results have a resource count over the given value\n" +
      "--max-duration-seconds N   Fail if any results have a duration over the given value in seconds\n" +
      "";

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
    var filePaths: seq<string> := [];
    var argIndex := 2;
    while argIndex < |args| {
      var arg := args[argIndex];
      match arg {
        case "--max-resource-count" => {
          :- Need(argIndex + 1 < |args|, "--max-resource-count must be followed by an argument\n\n" + helpText);
          argIndex := argIndex + 1;
          var count :- Externs.ParseNat(args[argIndex]);
          maxResourceCount := Some(count);
        }
        case "--max-duration-seconds" => {
          :- Need(argIndex + 1 < |args|, "--max-duration-seconds must be followed by an argument\n\n" + helpText);
          argIndex := argIndex + 1;
          var count :- Externs.ParseNat(args[argIndex]);
          maxDurationSeconds := Some(count);
        }
        case _ => {
          filePaths := filePaths + [arg];
        }
      }
      argIndex := argIndex + 1;
    }
    return Success(Options(maxDurationSeconds := maxDurationSeconds,
                           maxResourceCount := maxResourceCount, 
                           filePaths := filePaths));
  }
}
