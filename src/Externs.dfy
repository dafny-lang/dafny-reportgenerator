
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/BoundedInts.dfy"

module Externs {

  import opened Wrappers
  import opened BoundedInts

  method {:extern} GetCommandLineArgs() returns (args: seq<string>)
  method {:extern} SetExitCode(exitCode: uint8)

  method {:extern} FindAllCSVTestResultFiles(path: string) returns (lines: Result<seq<string>, string>)
  method {:extern} ReadAllFileLines(path: string) returns (lines: Result<seq<string>, string>)

  function {:extern} ParseNat(s: string): Result<nat, string>
  function {:extern} NatToString(n: nat): string
  function {:extern} ParseDurationTicks(s: string): Result<int64, string>
  function {:extern} DurationTicksToString(n: int64): string
  function {:extern} RealToString(n: real): string

  function {:extern} Sqrt(n: real): real

  const DurationTicksPerSecond := 10_000_000
}

