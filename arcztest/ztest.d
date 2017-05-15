module ztest is aliced;

import std.stdio;
import std.random;
import iv.arcz;


// ////////////////////////////////////////////////////////////////////////// //
enum ArcName = "z00.arz";
enum FileName = "arsd.cgi.Cgi.request.html";
enum DirName = "experimental-docs";


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  import std.stdio;
  ArzArchive arc;
  writeln("opening archive...");
  arc.openArchive(args.length > 1 ? args[1] : ArcName);
  writeln(arc.files.length, " files found");
  ubyte[] ofile;
  {
    auto fl = File(DirName~"/"~FileName);
    ofile = new ubyte[](cast(uint)fl.size);
    fl.rawRead(ofile[]);
  }

  auto fl = arc.open(args.length > 2 ? args[2] : FileName);
  writeln("size: ", fl.size);
  long opos = -1;
  foreach (immutable _; 0..1000000) {
    ubyte[1] b;
    uint npos = uniform!"[)"(0, fl.size);
    opos = fl.tell;
    fl.seek(npos);
    b[] = 0;
    auto r = fl.rawRead(b[]);
    if (r.length != b.length) {
      writeln("opos=", opos, "; npos=", npos);
      assert(0, "wtf00?!");
    }
    if (b[0] != ofile[npos]) {
      writeln("opos=", opos, "; npos=", npos, "; ofile[npos]=", ofile[npos], "; b[0]=", b[0]);
      assert(0, "wtf01?!");
    }
  }
}
