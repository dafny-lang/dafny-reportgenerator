
using System.Numerics;
using Dafny;
using Microsoft.Extensions.FileSystemGlobbing;
using Microsoft.Extensions.FileSystemGlobbing.Abstractions;
using Wrappers_Compile;
using icharseq = Dafny.ISequence<char>;
using charseq = Dafny.Sequence<char>;

namespace Externs_Compile {

  public partial class __default {
    public static Dafny.ISequence<icharseq> GetCommandLineArgs() {
      var dafnyArgs = Environment.GetCommandLineArgs().Select(charseq.FromString);
      return Dafny.Sequence<icharseq>.FromArray(dafnyArgs.ToArray());
    }
    
    public static void SetExitCode(int exitCode) {
      Environment.ExitCode = exitCode;
    }
    
    public static _IResult<ISequence<icharseq>, icharseq> FindAllCSVTestResultFiles(icharseq dafnyPath) {
      var path = dafnyPath.ToString();
      try {
        ISequence<icharseq> result;
        if (Directory.Exists(path)) {
          var matcher = new Matcher();
          matcher.AddInclude("**/TestResults/*.csv");
          var matcherResult = matcher.Execute(new DirectoryInfoWrapper(new DirectoryInfo(path)));
          result = Sequence<icharseq>.FromArray(matcherResult.Files.Select(file => 
            charseq.FromString(Path.Join(path, file.Path))).ToArray());
        } else {
          result = Sequence<icharseq>.FromElements(dafnyPath);
        }

        return Result<ISequence<icharseq>, icharseq>.create_Success(result);
      } catch (Exception e) {
        return Result<ISequence<icharseq>, icharseq>.create_Failure(charseq.FromString(e.Message));
      }
    }

    public static _IResult<ISequence<icharseq>, icharseq> ReadAllFileLines(icharseq dafnyPath) {
      var path = dafnyPath.ToString();
      try {
        var lines = File.ReadAllLines(path);
        var dafnyLines = Sequence<icharseq>.FromArray(lines.Select(charseq.FromString).ToArray());
        return Result<ISequence<icharseq>, icharseq>.create_Success(dafnyLines);
      } catch (Exception e) {
        return Result<ISequence<icharseq>, icharseq>.create_Failure(charseq.FromString(e.Message));
      }
    }

    public static _IResult<BigInteger, icharseq> ParseNat(icharseq dafnyString) {
      var s = dafnyString.ToString();
      try {
        return Result<BigInteger, icharseq>.create_Success(Int32.Parse(s));
      } catch (Exception e) {
        return Result<BigInteger, icharseq>.create_Failure(charseq.FromString(e.Message));
      }
    }

    public static icharseq NatToString(BigInteger n) {
      return charseq.FromString(n.ToString());
    }

    private static Double BigRationalToDouble(BigRational r) {
      if (r.den == 0) {
        return 0.0;
      } else {
        return (double)r.num / (double)r.den;
      }
    }

    public static icharseq RealToString(BigRational r) {
      return charseq.FromString(BigRationalToDouble(r).ToString());
    }

    public static BigRational Sqrt(BigRational r) {
      return new BigRational(Math.Sqrt(BigRationalToDouble(r)));
    }

    public static _IResult<long, icharseq> ParseDurationTicks(icharseq dafnyString) {
      var s = dafnyString.ToString();
      try {
        var timeSpan = TimeSpan.Parse(s);
        return Result<long, icharseq>.create_Success(timeSpan.Ticks);
      } catch (Exception e) {
        return Result<long, icharseq>.create_Failure(charseq.FromString(e.Message));
      }
    }
    
    public static icharseq DurationTicksToString(long ticks) {
      var timeSpan = TimeSpan.FromTicks(ticks);
      return charseq.FromString(timeSpan.ToString());
    }
  }
}
