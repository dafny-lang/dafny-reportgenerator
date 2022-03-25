include "../libraries/src/Collections/Sequences/Seq.dfy"
include "../libraries/src/Collections/Maps/Maps.dfy"

include "Externs.dfy"

module Statistics {
  import Externs
  import Seq

  function method Square(n: real): real { n * n }

  function method Sum(xs: seq<real>): real {
    Seq.FoldLeft((a, b) => a + b, 0.0, xs)
  }

  function method Mean(xs: seq<real>): real
    requires 0 < |xs|
  {
    Sum(xs) as real / |xs| as real
  }

  function method StdDev(xs: seq<real>): real
    requires 0 < |xs|
  {
    var mu := Mean(Seq.Map(x => x as real, xs));
    var variance := Mean(Seq.Map(x => Square(x as real - mu), xs));
    Externs.Sqrt(variance)
  }

  datatype Statistics = Statistics(
    min: real,
    max: real,
    mean: real,
    stddev: real
  ) {
    function method ToString(): string {
      "min: " + Externs.RealToString(min) + ", max: " + Externs.RealToString(max) +
      ", mean: " + Externs.RealToString(mean) + ", stddev: " + Externs.RealToString(stddev)
    }
  }

  function method StatisticsToSeconds(stats: Statistics): Statistics {
    Statistics(
      stats.min / Externs.DurationTicksPerSecond as real,
      stats.max / Externs.DurationTicksPerSecond as real,
      stats.mean / Externs.DurationTicksPerSecond as real,
      stats.stddev/ Externs.DurationTicksPerSecond as real
    )
  }
}
