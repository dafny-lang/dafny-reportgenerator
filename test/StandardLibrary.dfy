
include "../src/StandardLibrary.dfy"

module StandardLibraryTests {

  import opened StandardLibrary

  // Some run-of-the-mill sorting sanity tests.
  // Serves to also sanity check the specifications:
  // being able to verify these tests at all indicates
  // the pre-conditions are not impossible to satisfy.

  method {:test} EmptySequenceIsSorted() {
    expect SortedBy([], i => i);
  }

  method {:test} EmptySingetonSequenceIsSorted() {
    expect SortedBy([42], i => i);
  }

  method {:test} SomeSequenceIsSorted() {
    expect SortedBy([-3, 0, 42, 42, 500], i => i);
  }

  method {:test} SomeSequenceIsNotSorted() {
    expect !SortedBy([-3, 0, 42, 42, 500, 0], i => i);
  }

  method {:test} SortEmptySequence() {
    var sorted := MergeSortBy([], i => i);
    expect sorted == [];
  }

  method {:test} SortSingetonSequence() {
    var sorted := MergeSortBy([42], i => i);
    expect sorted == [42];
  }

  method {:test} SortSomeSequence() {
    var sorted := MergeSortBy([42, 0, 500, -3, 42], i => i);
    expect sorted == [-3, 0, 42, 42, 500];
  }

  // Stress test - stack overflow if the implementation is not tail-recursive
  method {:test} SortLargeSequence() {
    var unsorted := seq(10000, i => 9999 - i);
    var sorted := MergeSortBy(unsorted, i => i);
    expect sorted == seq(10000, i => i);
  }
}