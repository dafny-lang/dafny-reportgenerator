
include "../libraries/src/BoundedInts.dfy"
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/Collections/Sequences/Seq.dfy"
include "../libraries/src/Collections/Maps/Maps.dfy"

include "CSV.dfy"
include "Externs.dfy"

module TestResult {

  import opened BoundedInts
  import opened Wrappers

  import Externs
  import CSV
  import Maps
  import Seq

  datatype TestResult = TestResult(displayName: string, outcome: string, durationTicks: int64, resourceCount: nat) {
    function method ToString(): string {
      match this
      case TestResult(displayName, outcome, durationTicks, resourceCount) =>
        // TODO: extern for formatting duration
        displayName + "(" + outcome + ") - Duration = " + Externs.NatToString(resourceCount) +
                                    ", Resource Count = " + Externs.DurationTicksToString(durationTicks)
    }
  }

  method ParseTestResults(path: string) returns (result: Result<seq<TestResult>, string>) {
    var lines :- Externs.ReadAllFileLines(path);
    var table :- CSV.ParseDataWithHeader(lines);
    result := Seq.MapWithResult(ParseFromCSVRow, table);
  }

  const DISPLAY_NAME := "TestResult.DisplayName";
  const OUTCOME := "TestResult.Outcome";
  const DURATION := "TestResult.Duration";
  const RESOURCE_COUNT := "TestResult.ResourceCount";

  function method GetCSVRowField(row: CSV.Row, fieldName: string): Result<string, string> {
    :- Need(fieldName in row, "Field missing in row: " + fieldName);
    Success(row[fieldName])
  }

  function method ParseFromCSVRow(row: CSV.Row): Result<TestResult, string> {
    var displayName :- GetCSVRowField(row, DISPLAY_NAME);
    var outcome :- GetCSVRowField(row, OUTCOME);
    var durationStr :- GetCSVRowField(row, DURATION);
    var durationTicks :- Externs.ParseDurationTicks(durationStr);
    var resourceCountStr :- GetCSVRowField(row, RESOURCE_COUNT);
    var resourceCount :- Externs.ParseNat(resourceCountStr);
    Success(TestResult(displayName, outcome, durationTicks, resourceCount))
  }
}