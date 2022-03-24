
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

    private static bool TryBigRationalToDouble(BigRational r, out Double d) {
      // This is kind of ridiculous. We could certainly improve the BigRational
      // class to make stuff like this easier. Conversion to and from `double`
      // would probably be worth including.
      string rStr = r.ToString();
      double num, den;
      if(Double.TryParse(rStr, out var result)) {
        d = result;
        return true;
      }
      var parts = r.ToString().Trim(new char[] {'(', ')'}).Split('/', StringSplitOptions.TrimEntries);
      if(parts.Length != 2) {
        d = 0.0;
        return false;
      }
      if(!Double.TryParse(parts[0], out num)) {
        d = 0.0;
        return false;
      }
      if(!Double.TryParse(parts[1], out den)) {
        d = 0.0;
        return false;
      }
      d = num / den;
      return true;
    }

    public static icharseq RealToString(BigRational r) {
      if(TryBigRationalToDouble(r, out var d)) {
        return charseq.FromString(d.ToString());
      } else {
        return charseq.FromString("Failed to convert real to string");
      }
    }

    public static BigRational Sqrt(BigRational r) {
      if(TryBigRationalToDouble(r, out var d)) {
        var sqrt = Math.Sqrt(d);
        double multiplier = 1000000000.0;
        return new BigRational(
                 new BigInteger(sqrt * multiplier),
                 new BigInteger((long)multiplier));
      } else {
        return new BigRational(-1, 1);
      }
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
