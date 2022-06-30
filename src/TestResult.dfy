
include "../libraries/src/BoundedInts.dfy"
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/Collections/Sequences/Seq.dfy"
include "../libraries/src/Collections/Maps/Maps.dfy"

include "CSV.dfy"
include "Externs.dfy"
include "StandardLibrary.dfy"
include "Statistics.dfy"

module TestResult {

  import opened BoundedInts
  import opened Wrappers

  import Externs
  import CSV
  import Maps
  import Seq
  import StandardLibrary
  import Statistics

  datatype TestResult = TestResult(displayName: string, outcome: string, durationTicks: int64, resourceCount: nat) {
    function method ToString(): string {
      displayName + "(" + outcome + ") - Duration = " + Externs.DurationTicksToString(durationTicks) +
                                ", Resource Count = " + Externs.NatToString(resourceCount)
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

  method GroupTestResults(results: seq<TestResult>) returns (groupedResults: map<string, seq<TestResult>>) {
    groupedResults := map[];
    for resIndex := 0 to |results| {
      var res := results[resIndex];
      var name := res.displayName;
      if name in groupedResults {
        groupedResults := groupedResults[name := groupedResults[name] + [res]];
      } else {
        groupedResults := groupedResults[name := [res]];
      }
    }
  }

  predicate method ConsistentOutcomes(results: seq<TestResult>) {
    |set result <- results :: result.outcome| == 1
  }

  function method TestResultStatistics(results: seq<TestResult>, f: TestResult -> real): Statistics.Statistics
  {
    if 0 < |results| then
      var min := StandardLibrary.MinRealSeq(Seq.Map(f, results));
      var max := StandardLibrary.MaxRealSeq(Seq.Map(f, results));
      var mean := Statistics.Mean(Seq.Map(x => f(x), results));
      var stddev := Statistics.StdDev(Seq.Map(x => f(x), results));
      Statistics.Statistics(min, max, mean, stddev)
    else
      Statistics.Statistics(0.0, 0.0, 0.0, 0.0)
  }

  function method TestResultDurationStatistics(results: seq<TestResult>): Statistics.Statistics
  {
    TestResultStatistics(results, (result: TestResult) => result.durationTicks as real)
  }

  function method TestResultResourceStatistics(results: seq<TestResult>): Statistics.Statistics
  {
    TestResultStatistics(results, (result: TestResult) => result.resourceCount as real)
  }

  method PrintTestResultStatistics(displayName: string, results: seq<TestResult>)
  {
    var timeStats := TestResultDurationStatistics(results);
    var resStats := TestResultResourceStatistics(results);
    print displayName, "\n";
    print "  Time (seconds) - ", Statistics.StatisticsToSeconds(timeStats).ToString(), "\n";
    print "  Resource count - ", resStats.ToString(), "\n";
    print "  Consistent outcomes - ", ConsistentOutcomes(results), "\n";
  }

  method PrintAllTestResultStatistics(groupedResults: map<string, seq<TestResult>>)
  {
    var resultBatches := groupedResults.Items;
    while resultBatches != {}
      decreases |resultBatches|
    {
      var resultBatch :| resultBatch in resultBatches;
      resultBatches := resultBatches - {resultBatch};
      if 0 < |resultBatch.1| { // TODO: could prove that this never happens
        PrintTestResultStatistics(resultBatch.0, resultBatch.1);
      }
    }
  }

  method MapResultGroups<T(==)>(groupedResults: map<string, seq<TestResult>>, f: (string, seq<TestResult>) -> T)
      returns (res: seq <(string, T)>)
  {
    res := StandardLibrary.MapToSeq(map k | k in groupedResults :: f(k, groupedResults[k]));
  }

  method ResultGroupStatistics(groupedResults: map<string, seq<TestResult>>, f: seq<TestResult> -> real)
    returns (res: seq <(string, real)>)
  {
    res := MapResultGroups(groupedResults, (name, results) => f(results));
  }

  method ResultGroupConsistency(groupedResults: map<string, seq<TestResult>>)
    returns (res: seq <(string, bool)>)
  {
    res := MapResultGroups(groupedResults, (name, results) => ConsistentOutcomes(results));
  }
}
