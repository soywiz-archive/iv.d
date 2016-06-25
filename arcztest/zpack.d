module zpack;

import core.time;
import std.stdio;

import iv.arcz;


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
void doMain (string[] args) {
  import std.file, std.path, std.stdio : File;

  // -1: error
  long parseSize (const(char)[] s) {
    if (s.length == 0) return -1;
    if (s[0] < '0' || s[0] > '9') return -1;
    long res = 0;
    while (s.length && s[0] >= '0' && s[0] <= '9') {
      res = res*10+s[0]-'0';
      if (res > 0x3fff_ffff) return -1;
      s = s[1..$];
    }
    if (s.length == 0) return res;
    if (s.length == 1) {
      switch (s[0]) {
        case 'K': case 'k': return res*1024;
        case 'M': case 'm': return res*1024*1024;
        case 'G': case 'g': return res*1024*1024*1024;
        default: return -1;
      }
    } else if (s.length == 2) {
      char[2] u;
      foreach (immutable idx, char ch; s) {
        if (ch >= 'a' && ch <= 'z') ch -= 32;
        u[idx] = ch;
      }
      switch (u[]) {
        case "KB": return res*1024;
        case "MB": return res*1024*1024;
        case "GB": return res*1024*1024*1024;
        default: return -1;
      }
    }
    return -1;
  }

  uint blockSize = 256*1024;

  void usage () {
    import std.stdio : write;
    write(
      "zpack [options] -o outfile sourcedir\n"~
      "options:\n"~
      "  -b     block size [1..32MB] (default is 256KB)\n"~
      "  --balz use Balz compressor instead of zlib\n"
    );
  }

  string outfname = null;
  string srcdir = null;
  bool useBalz = false;

  ubyte[] rdbuf;
  rdbuf.length = 65536;

  if (args.length < 2) { usage(); return; }

  bool nomore = false;
  int f = 1;
  while (f < args.length) {
    string arg = args[f++];
    if (arg.length == 0) continue;
    if (!nomore) {
      if (arg == "--") { nomore = true; continue; }
      if (arg == "-") throw new Exception("stdin is not supported");
      if (arg[0] == '-') {
        if (arg == "--balz") { useBalz = true; continue; }
        if (arg[1] == '-') throw new Exception("long options aren't supported");
        arg = arg[1..$];
        while (arg.length) {
          char ch = arg[0];
          arg = arg[1..$];
          if (ch == 'b') {
            if (arg.length == 0) {
              if (f >= args.length) throw new Exception("block size?");
              arg = args[f++];
            }
            auto sz = parseSize(arg);
            if (sz < 1 || sz >= 32*1024*1024) throw new Exception("invalid block size: '"~arg~"'");
            blockSize = cast(uint)sz;
            break;
          }
          if (ch == 'h') { usage(); return; }
          if (ch == 'o') {
            if (outfname !is null) throw new Exception("duplicate output name");
            if (arg.length == 0) {
              if (f >= args.length) throw new Exception("block size?");
              arg = args[f++];
            }
            if (arg.length == 0) throw new Exception("empty output name");
            outfname = arg.defaultExtension(".arz");
            break;
          }
          throw new Exception("invalid option: '"~ch~"' ("~arg~")");
        }
        continue;
      }
    }
    if (srcdir !is null) throw new Exception("duplicate source directory");
    if (arg == "-") throw new Exception("stdin is not supported");
    srcdir = arg;
  }

  if (srcdir is null) throw new Exception("source directory?");
  if (outfname is null) throw new Exception("output file name?");

  writeln("creating archive '", outfname, "' with block size ", blockSize.n2c);

  static struct FInfo {
    string diskname;
    string name;
    uint size;
  }
  FInfo[] filelist;

  writeln("building file list...");
  long total = 0;
  foreach (DirEntry e; dirEntries(srcdir, SpanMode.breadth)) {
    if (e.isFile) {
      if (e.size > 0x3fff_ffff) throw new Exception("file '"~e.name~"' is too big");
      total += e.size;
      string fname = e.name[srcdir.length..$];
      version(Windows) {
        import std.string : replace;
        while (fname.length > 0 && fname[0] == '\\') fname = fname[1..$];
        fname = fname.replace("\\", "/");
      } else {
        while (fname.length > 0 && fname[0] == '/') fname = fname[1..$];
      }
      if (fname.length == 0) throw new Exception("invalid file name (wtf?!)");
      filelist ~= FInfo(e.name, fname, cast(uint)e.size);
    }
  }

  if (filelist.length == 0) throw new Exception("no files found");
  writeln(filelist.length, " files found, total ", total.n2c, " bytes");

  // sort files by size and extension
  import std.algorithm : sort;
  /*
  filelist.sort!((ref a, ref b) {
    if (a.size < b.size) return true;
    if (a.size > b.size) return false;
    // same size, try extension
    return (a.name.extension < b.name.extension);
  });
  */
  filelist.sort!((ref a, ref b) {
    // same size, try extension
    return (a.name < b.name);
  });

  auto arcz = new ArzCreator(outfname, blockSize, useBalz);
  auto stt = MonoTime.currTime;
  foreach (immutable filenum, ref nfo; filelist) {
    arcz.newFile(nfo.name, nfo.size);
    auto fi = File(nfo.diskname);
    for (;;) {
      auto rd = fi.rawRead(rdbuf[]);
      if (rd.length == 0) break;
      arcz.rawWrite(rd[]);
    }
    {
      auto ctt = MonoTime.currTime;
      if ((ctt-stt).total!"seconds" > 0) {
        stt = ctt;
        stdout.write("\r[", (filenum+1).n2c, "/", filelist.length.n2c, "] files processed");
        stdout.flush();
      }
    }
  }
  arcz.close();
  writeln("\r", total.n2c, " bytes packed to ", getSize(outfname).n2c, " (", arcz.chunksWritten, " chunks, ", arcz.filesWritten, " files)\x1b[K");
}


// ////////////////////////////////////////////////////////////////////////// //
int main (string[] args) {
  try {
    doMain(args);
    return 0;
  } catch (Exception e) {
    writeln("FATAL: ", e.msg);
  }
  return -1;
}
