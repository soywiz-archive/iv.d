module zlist /*is aliced*/;

import iv.alice;
import iv.arcz;


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  import std.stdio;
  ArzArchive arc;
  writeln("opening archive...");
  arc.openArchive((args.length > 1 ? args[1] : "z00.arz"));
  writeln(arc.files.length, " files found");
  debug(arcz_rc) {
    {
      ArzArchive a0;
      a0 = arc;
    }
    {
      auto a1 = ArzArchive(arc);
    }
  }
  {
    auto fl = arc.open((args.length > 2 ? args[2] : "simpledisplay.Timer.fd.html"));
    writeln("size: ", fl.size);
    auto buf = new char[](fl.size);
    auto rd = fl.rawRead(buf[]);
    assert(rd.length == buf.length);
    writeln(buf[]);
  }
}
