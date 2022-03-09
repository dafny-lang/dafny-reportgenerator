
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/Collections/Sequences/Seq.dfy"

include "StandardLibrary.dfy"
module CSV {

  import opened Wrappers
  import opened Seq
  import opened StandardLibrary

  type Row = map<string, string>
  type Table = seq<Row>

  function method ParseDataWithHeader(lines: seq<string>): Result<Table, string> {
    :- Need(|lines| > 0, "Must have at least one row");
    var header := ParseRow(lines[0]);

    :- Need(|ToSet(header)| == |header|, "Header row must not have duplicates");
    LemmaNoDuplicatesCardinalityOfSet(header);
    var parseRow := line => ParseRowWithHeader(header, line);
    
    var rows :- Seq.MapWithResult(parseRow, lines[1..]);
    Success(rows)
  }

  function method ParseRowWithHeader(header: seq<string>, line: string): Result<Row, string>
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
}
