
include "../libraries/src/Wrappers.dfy"
include "../libraries/src/Collections/Sequences/Seq.dfy"

// Utilities that should probably be moved into dafny-lang/libraries
// before too long.
module StandardLibrary {

  import opened Wrappers
  import opened Seq

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

  // TODO: These are not very generic since there's no type characteristic for "comparable".
  // This version is all I need here, but this could be more general if a comparison function
  // was provided instead.

  predicate SortedBy<T>(s: seq<T>, f: T -> int) {
    forall i, j | 0 <= i < j < |s| :: f(s[i]) <= f(s[j])
  }

  lemma LemmaNewFirstElementStillSortedBy<T>(x: T, s: seq<T>, f: T -> int) 
    requires SortedBy(s, f)
    requires |s| == 0 || f(x) <= f(s[0])
    ensures SortedBy([x] + s, f)
  {}

  function method MergeSortBy<T>(s: seq<T>, f: T -> int): (result: seq<T>)
    ensures SortedBy(result, f)
    ensures multiset(s) == multiset(result)
  {
    if |s| <= 1 then
      s
    else
      var splitIndex := |s| / 2;
      var left := s[..splitIndex];
      var right := s[splitIndex..];
      assert s == left + right;

      var leftSorted := MergeSortBy(left, f);
      var rightSorted := MergeSortBy(right, f);
      
      MergeSortedBy(leftSorted, rightSorted, f)
  }

  // TODO: How to add {:tailrecursion} while keeping the assertions necessary to prove the post-conditions?
  function method MergeSortedBy<T>(left: seq<T>, right: seq<T>, f: T -> int): (result: seq<T>)
    requires SortedBy(left, f)
    requires SortedBy(right, f)
    ensures SortedBy(result, f)
    ensures multiset(left + right) == multiset(result)
  {
    if |left| == 0 then
      right
    else if |right| == 0 then
      left
    else if f(right[0]) < f(left[0]) then
      var rest := MergeSortedBy(left, right[1..], f);
      var result := [right[0]] + rest;
      LemmaNewFirstElementStillSortedBy(right[0], rest, f);
      assert right == [right[0]] + right[1..];
      result
    else
      var rest := MergeSortedBy(left[1..], right, f);
      LemmaNewFirstElementStillSortedBy(left[0], rest, f);
      assert left == [left[0]] + left[1..];
      [left[0]] + rest
  }
}