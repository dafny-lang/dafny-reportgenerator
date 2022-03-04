
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/BoundedInts.dfy"

module Externs {

  import opened Wrappers
  import opened BoundedInts

  method {:extern} GetCommandLineArgs() returns (args: seq<string>)
  method {:extern} SetExitCode(exitCode: uint8)

  method {:extern} ReadAllFileLines(path: string) returns (lines: Result<seq<string>, string>)

  function method {:extern} ParseNat(s: string): Result<nat, string>
  function method {:extern} ParseDuration(s: string): Result<nat, string>
}

