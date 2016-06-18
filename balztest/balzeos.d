module balztest;

import iv.balz;


// ////////////////////////////////////////////////////////////////////////// //
string n2c (ulong n) {
  import std.conv : to;
  string t = to!string(n);
  if (t.length < 4) return t;
  string res;
  while (t.length > 3) {
    res = ","~t[$-3..$]~res;
    t = t[0..$-3];
  }
  if (t.length) res = t~res; else res = res[1..$];
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
version = show_progress;

int main (string[] args) {
  import core.time;
  import core.stdc.time;
  import std.stdio;

  if (args.length != 4) {
    write(
      "BALZ - A ROLZ-based file compressor, v1.20\n"~
      "\n"~
      "Usage: BALZ command infile outfile\n"~
      "\n"~
      "Commands:\n"~
      "  c|cx Compress (Normal|Maximum)\n"~
      "  d|x  Decompress\n"
    );
    return 1;
  }

  auto fin = File(args[2]);
  auto fout = File(args[3], "w");

  if (args[1][0] == 'c') {
    Balz bz;
    writefln("Compressing: %s -> %s", args[2], args[3]);
    long fsz = fin.size;
    fout.rawWrite((&fsz)[0..1]);
    version(show_progress) {
      auto stt = MonoTime.currTime;
      long totalRead = 0;
      long totalWritten = 0;
      long prevRead = 0, prevWritten = 0;

      void progress () {
        if (prevRead == 0 || prevWritten == 0 || totalRead-prevRead >= 1024*1024 || totalWritten-prevWritten >= 1024*1024) {
          auto ctt = MonoTime.currTime;
          if ((ctt-stt).total!"seconds" > 0) {
            stt = ctt;
            prevRead = totalRead;
            prevWritten = totalWritten;
            stdout.write("\r[", totalRead.n2c, "/", fsz.n2c, "] [", totalWritten.n2c, "]");
            stdout.flush();
          }
        }
      }
    }
    auto start = clock();
    bz.compress(
      // reader
      (buf) {
        auto res = fin.rawRead(buf[]);
        version(show_progress) {
          totalRead += res.length;
          progress();
        }
        return cast(uint)res.length;
      },
      // writer
      (buf) {
        fout.rawWrite(buf[]);
        version(show_progress) {
          totalWritten += buf.length;
          progress();
        }
      },
      // mode
      args[1].length > 1 && args[1][1] == 'x'
    );
    writefln("\r%s -> %s in %.3fs\x1b[K", fin.size.n2c, fout.size.n2c, double(clock()-start)/CLOCKS_PER_SEC);
  } else if (args[1][0] == 'd' || args[1][0] == 'x') {
    Unbalz bz;
    writefln("Decompressing: %s -> %s", args[2], args[3]);
    long fsz;
    fin.rawRead((&fsz)[0..1]);
    auto start = clock();
    //auto stt = MonoTime.currTime;
    auto dc = bz.decompress(
      // reader
      (buf) { auto res = fin.rawRead(buf[]); return cast(uint)res.length; },
      // writer
      (buf) { fout.rawWrite(buf[]); },
    );
    if (dc != fsz) writeln("INVALID STREAM SIZE: got ", dc, " but expected ", fsz);
    writefln("%s -> %s in %.3fs", fin.size.n2c, fout.size.n2c, double(clock()-start)/CLOCKS_PER_SEC);
  } else {
    writefln("Unknown command: %s", args[1]);
    return 1;
  }

  return 0;
}
