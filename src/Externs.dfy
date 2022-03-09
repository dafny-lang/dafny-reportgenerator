
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/BoundedInts.dfy"

module Externs {

  import opened Wrappers
  import opened BoundedInts

  method {:extern} GetCommandLineArgs() returns (args: seq<string>)
  method {:extern} SetExitCode(exitCode: uint8)

  method {:extern} ReadAllFileLines(path: string) returns (lines: Result<seq<string>, string>)

  function method {:extern} ParseNat(s: string): Result<nat, string>
  function method {:extern} NatToString(n: nat): string
  function method {:extern} ParseDurationTicks(s: string): Result<int64, string>
  function method {:extern} DurationTicksToString(n: int64): string

  const DurationTicksPerSecond := 10_000_000;
}

