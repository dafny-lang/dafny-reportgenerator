
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/BoundedInts.dfy"

include "CSV.dfy"
include "Externs.dfy"
include "TestResult.dfy"
module Main {

  import opened Wrappers

  import CSV
  import Externs
  import TestResult
  
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
    :- Need(|args| == 2, "Not enough arguments.");
    var path := args[1];
    result := ProcessFile(path);
  }

  method ProcessFile(path: string) returns (result: Result<(), string>) {
    var lines :- Externs.ReadAllFileLines(path);
    var table :- CSV.ParseDataWithHeader(lines);
    var passed := true;
    for i := 0 to |table| {
      var overlimit :- TestResult.ResourceCountOverLimit(table[i], 2);
      if overlimit {
        print "Over the limit: \n", table[i], "\n";
        passed := false;
      }
    }
    :- Need(passed, "Some results were over the limit!\n");
    return Success(());
  }
}