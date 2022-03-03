
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/BoundedInts.dfy"

include "CSV.dfy"
module Externs {

  import opened Wrappers
  import opened BoundedInts

  method {:extern} GetCommandLineArgs() returns (args: seq<string>)
  method {:extern} SetExitCode(exitCode: uint8)
  method {:extern} ReadAllFileLines(path: string) returns (lines: Result<seq<string>, string>)
}

module Main {

  import opened Wrappers

  import Externs
  import CSV

  method Main() {
    // Working around the lack of arguments or return value from main methods.
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
    print table;
  }
}