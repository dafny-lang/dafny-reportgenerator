
include "../libraries/src/BoundedInts.dfy"
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/Collections/Sequences/Seq.dfy"
include "../libraries/src/Collections/Maps/Maps.dfy"

include "CSV.dfy"
include "Externs.dfy"
include "Statistics.dfy"

module TestResult {

  import opened BoundedInts
  import opened Wrappers

  import Externs
  import CSV
  import Maps
  import Seq
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

  function method TestResultStatistics(results: seq<TestResult>, f: TestResult -> int): Statistics.Statistics
  {
    match 0 < |results| {
      case true =>
        var min := Seq.Min(Seq.Map(f, results));
        var max := Seq.Max(Seq.Map(f, results));
        var mean := Statistics.Mean(Seq.Map(x => f(x) as real, results));
        var stddev := Statistics.StdDev(Seq.Map(x => f(x) as real, results));
        Statistics.Statistics(min as real, max as real, mean, stddev)
      case false =>
        Statistics.Statistics(0.0, 0.0, 0.0, 0.0)
    }
  }

  function method TestResultDurationStatistics(results: seq<TestResult>): Statistics.Statistics
  {
    TestResultStatistics(results, (result: TestResult) => result.durationTicks as int)
  }

  function method TestResultResourceStatistics(results: seq<TestResult>): Statistics.Statistics
  {
    TestResultStatistics(results, (result: TestResult) => result.resourceCount)
  }

  method PrintTestResultStatistics(displayName: string, results: seq<TestResult>)
  {
    var timeStats := TestResultStatistics(results, (r: TestResult) => r.durationTicks as int);
    var resStats := TestResultStatistics(results, (r: TestResult) => r.resourceCount as int);
    print displayName, "\n";
    print "  Time - ", Statistics.StatisticsToSeconds(timeStats).ToString(), "\n";
    print "  Resource Count - ", resStats.ToString(), "\n";
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

  // TODO: there must be an easier way to map a function over a map
  method MapResultGroups<T>(groupedResults: map<string, seq<TestResult>>, f: (string, seq<TestResult>) -> T)
    returns (res: seq <(string, T)>)
  {
    var resultBatches := groupedResults.Items;
    res := [];
    while resultBatches != {}
      decreases |resultBatches|
    {
      var resultBatch :| resultBatch in resultBatches;
      resultBatches := resultBatches - {resultBatch};
      if 0 < |resultBatch.1| { // TODO: could prove that this never happens
        res := res + [(resultBatch.0, f(resultBatch.0, resultBatch.1))];
      }
    }
  }

  method ResultGroupResourceStddevs(groupedResults: map<string, seq<TestResult>>)
    returns (res: seq <(string, real)>)
  {
    res := MapResultGroups(groupedResults, (name, results) => TestResultResourceStatistics(results).stddev);
  }

  method ResultGroupDurationStddevs(groupedResults: map<string, seq<TestResult>>)
    returns (res: seq <(string, real)>)
  {
    res := MapResultGroups(groupedResults, (name, results) => TestResultDurationStatistics(results).stddev);
  }
}
