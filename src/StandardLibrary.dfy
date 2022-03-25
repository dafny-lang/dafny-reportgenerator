
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

  // TODO: This version is all I need here, but this could be more general if a comparison function
  // was provided instead.

  // TODO: Make this a predicate-by-method so it has linear runtime instead of quadratic.
  // For now it's only used at runtime in tests.
  predicate method SortedBy<T>(s: seq<T>, f: T -> int) {
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
      var left, right := s[..splitIndex], s[splitIndex..];
      assert s == left + right;

      var leftSorted := MergeSortBy(left, f);
      var rightSorted := MergeSortBy(right, f);
      
      MergeSortedBy(leftSorted, rightSorted, f)
  }

  function method {:tailrecursion} MergeSortedBy<T>(left: seq<T>, right: seq<T>, f: T -> int): (result: seq<T>)
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
      LemmaNewFirstElementStillSortedBy(right[0], MergeSortedBy(left, right[1..], f), f);
      assert right == [right[0]] + right[1..];

      [right[0]] + MergeSortedBy(left, right[1..], f)
    else
      LemmaNewFirstElementStillSortedBy(left[0], MergeSortedBy(left[1..], right, f), f);
      assert left == [left[0]] + left[1..];

      [left[0]] +  MergeSortedBy(left[1..], right, f)
  }

  method SetToSeq<T>(s: set<T>)
    returns (resultSeq: seq<T>)
  {
    var entrySet := s;
    resultSeq := [];
    while entrySet != {}
      decreases |entrySet|
    {
      var entry :| entry in entrySet;
      entrySet := entrySet - {entry};
      resultSeq := resultSeq + [entry];
    }
  }

  method MapToSeq<K(==), V(==)>(m: map<K, V>)
    returns (resultSeq: seq<(K, V)>)
  {
    resultSeq := SetToSeq(m.Items);
  }
}