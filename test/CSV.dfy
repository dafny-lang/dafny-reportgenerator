
include "../src/CSV.dfy"

module CSVTests {

  import CSV

  method {:test} ParseDataWithHeader() {
    var lines := ["A,B,C", "1,2,3", "4,5,6"];
    var data :- expect CSV.ParseDataWithHeader(lines);
    var expectedTable := [
      map["A" := "1", "B" := "2", "C" := "3"],
      map["A" := "4", "B" := "5", "C" := "7"]
    ];
    expect data == expectedTable;
  }

}