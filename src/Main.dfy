
module Externs {
  method {:extern} GetCommandLineArgs() returns (args: seq<string>)
}

method Main() {
  var args := Externs.GetCommandLineArgs();
  print "Args: ", args, "\n";
}