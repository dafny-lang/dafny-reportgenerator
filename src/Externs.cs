
using Dafny;
using icharseq = Dafny.ISequence<char>;
using charseq = Dafny.Sequence<char>;

namespace Externs_Compile {

  public partial class __default {
    public static Dafny.ISequence<icharseq> GetCommandLineArgs() {
      var dafnyArgs = Environment.GetCommandLineArgs().Select(charseq.FromString);
      return Dafny.Sequence<icharseq>.FromArray(dafnyArgs.ToArray());
    }
  }
}