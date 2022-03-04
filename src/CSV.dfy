
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/Collections/Sequences/Seq.dfy"

module CSV {

  import opened Wrappers
  import opened Seq

  type CSVRow = map<string, string>
  type CSVTable = seq<CSVRow>

  function method ParseDataWithHeader(lines: seq<string>): Result<CSVTable, string> {
    :- Need(|lines| > 0, "Must have at least one row");
    var header := ParseRow(lines[0]);
    :- Need(|ToSet(header)| == |header|, "Header row must not have duplicates");
    LemmaNoDuplicatesCardinalityOfSet(header);
    var parseRow := line => ParseRowWithHeader(header, line);
    var rows :- Seq.MapWithResult(parseRow, lines[1..]);
    Success(rows)
  }

  function method ParseRowWithHeader(header: seq<string>, line: string): Result<CSVRow, string>
    requires HasNoDuplicates(header)
  {
    var row := ParseRow(line);
    :- Need(|row| == |header|, "Wrong number of columns in row");
    reveal HasNoDuplicates();
    Success(map i | 0 <= i < |header| :: header[i] := row[i])
  }

  function method ParseRow(line: string): seq<string> {
    Split(line, ',')
  }

  // Could be added to the standard library as well
  function method {:tailrecursion} Split<T(==)>(s: seq<T>, separator: T): seq<seq<T>> 
    decreases |s|
  {
    var indexOption := IndexOfOption(s, separator);
    match indexOption
    case Some(index) =>
      [s[0..index]] + Split(s[index + 1..|s|], separator)
    case None =>
      [s]
  }
}