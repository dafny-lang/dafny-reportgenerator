
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
  
  datatype Options = Options(maxResourceCount: Option<nat>, filePaths: seq<string>)

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

  method MainAux(args: seq<string>) returns (result: Result<(), string>) {
    var options :- ParseCommandLineOptions(args);
    
    // Here I really wish I could use MapWithResult on a method-based Action instead of just a function :(
    var allResults := [];
    for pathIndex := 0 to |options.filePaths| {
      var resultsBatch :- ParseTestResults(options.filePaths[pathIndex]);
      allResults := allResults + resultsBatch;
    }

    var resourceCountGetter := (r: TestResult.TestResult) => r.resourceCount;
    var allResultsSortedByResourceCount := StandardLibrary.MergeSortBy(allResults, resourceCountGetter);
    
    print "All results: \n\n";
    for i := 0 to |allResultsSortedByResourceCount| {
      print allResultsSortedByResourceCount[i].ToString(), "\n";
    }

    if options.maxResourceCount.Some? {
      var allResultsOverLimit := Filter(r => TestResult.ResourceCountOverLimit(r, options.maxResourceCount.value), allResultsSortedByResourceCount);
      if 0 < |allResultsOverLimit| {
        print "\n";
        print "Some results have a resource count over the configured limit of ", options.maxResourceCount.value, ":\n\n";
        for i := 0 to |allResultsOverLimit| {
          print allResultsOverLimit[i].ToString(), "\n";
        }
        return Failure("\nErrors occurred: see above\n");
      }
    }

    return Success(());
  }

  method ParseCommandLineOptions(args: seq<string>) returns (result: Result<Options, string>) {
    // For now only one top-level command
    :- Need(|args| >= 2, "Not enough arguments.");
    :- Need(args[1] == "summarize-csv-results", "The only supported command is `summarize-csv-results`");

    var maxResourceCount: Option<nat> := None;
    var filePaths: seq<string> := [];
    var argIndex := 2;
    while argIndex < |args| {
      var arg := args[argIndex];
      match arg {
        case "--max-resource-count" => {
          :- Need(argIndex + 1 < |args|, "--max-resource-count must be followed by the maximum count");
          argIndex := argIndex + 1;
          var count :- Externs.ParseNat(args[argIndex]);
          maxResourceCount := Some(count);
        }
        case _ => {
          filePaths := filePaths + [arg];
        }
      }
      argIndex := argIndex + 1;
    }
    return Success(Options(maxResourceCount, filePaths));
  }
}