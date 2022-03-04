
include "../libraries/src/Wrappers.dfy"

include "Externs.dfy"

module TestResult {

  import opened Wrappers

  import Externs

  const DISPLAY_NAME := "TestResult.DisplayName";
  const OUTCOME := "TestResult.Outcome";
  const DURATION := "TestResult.Duration";
  const RESOURCE_COUNT := "TestResult.ResourceCount";

  function method ResourceCountOverLimit(testResult: map<string, string>, maximumResourceCount: nat): Result<bool, string> {
    :- Need(RESOURCE_COUNT in testResult, "Missing ResourceCount entry");
    var resourceCountStr := testResult[RESOURCE_COUNT];
    var resourceCount :- Externs.ParseNat(resourceCountStr);
    Success(maximumResourceCount < resourceCount)
  }
}