#!/usr/bin/env rdmd
module xzippack is aliced;

import iv.cmdcon;
import iv.glob;
import iv.strex;
import iv.unarray;
import iv.vfs;
import iv.vfs.util;
import iv.vfs.writers.zip;


// ////////////////////////////////////////////////////////////////////////// //
struct FileInfo {
  enum Type { Normal, Dir }

  string name;
  ulong size;
  Type type;
  uint modtime;
  uint stmode;
  ulong inode;

  this (const(char)[] aname) {
    import core.sys.posix.sys.stat;
    import std.internal.cstring : tempCString;
    stat_t st;
    if (stat(aname.tempCString, &st) != 0) throw new Exception("cannot stat '"~aname.idup~"'");
    if (st.st_mode.S_ISDIR) {
      type = Type.Dir;
    } else if (st.st_mode.S_ISREG) {
      type = Type.Normal;
      size = st.st_size;
    } else if (st.st_mode.S_ISLNK) {
      throw new Exception("don't know what to do with symlink '"~aname.idup~"'");
    } else {
      throw new Exception("don't know what to do with special file '"~aname.idup~"'");
    }
    name = aname.idup;
    if (type == Type.Dir && name[$-1] != '/') name ~= '/';
    modtime = st.st_mtime;
    inode = st.st_ino;
    stmode = st.st_mode;
  }

  @property ushort unixmode () const pure nothrow @safe @nogc { pragma(inline, true); return (stmode&ushort.max); }

  @property string baseName () const pure nothrow @safe @nogc {
    if (name.length == 0) return null;
    string res = name;
    if (type == Type.Dir) {
      if (res[$-1] != '/') assert(0, "internal error");
      if (res == "/") return res;
      res = res[0..$-1];
    }
    if (res.length == 0) assert(0, "internal error");
    foreach (immutable pos, char ch; res; reverse) {
      if (ch == '/') {
        if (pos+1 == res.length) assert(0, "internal error");
        return res[pos+1..$];
      }
    }
    return res;
  }

  @property string dirName () const pure nothrow @safe @nogc {
    if (name.length == 0) return null;
    string res = name;
    if (type == Type.Dir) {
      if (res[$-1] != '/') assert(0, "internal error");
      if (res == "/") return res;
      res = res[0..$-1];
    }
    if (res.length == 0) assert(0, "internal error");
    foreach (immutable pos, char ch; res; reverse) {
      if (ch == '/') {
        if (pos == 0) return "/";
        return res[0..pos];
      }
    }
    return ".";
  }

  @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (name.length != 0); }
  @property bool isDir () const pure nothrow @safe @nogc { pragma(inline, true); return (type == Type.Dir); }
  @property bool isFile () const pure nothrow @safe @nogc { pragma(inline, true); return (type == Type.Normal); }

  bool opEquals() (in auto ref FileInfo fi) const pure nothrow @safe @nogc {
    pragma(inline, true);
    return (name == fi.name);
  }

  int opCmp() (in auto ref FileInfo fi) const pure nothrow @safe @nogc {
    pragma(inline, true);
    if (name == fi.name) {
      if (type != fi.type) return (type == Type.Dir ? -1 : 1); // dirs are always first
      return 0;
    } else {
      return (name < fi.name ? -1 : name > fi.name ? 1 : 0);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared FileInfo[] diskFileList;
__gshared bool[ulong] diskFilesSeen; // by inode
__gshared ulong totalDiskSize;


void scanDisk (string nameorpath) {
  if (nameorpath.length == 0) return;

  auto cfi = FileInfo(nameorpath);
  //conwriteln("nameorpath: [", nameorpath, "] : [", cfi.name, "]; inode=", cfi.inode, "; mode=", cfi.stmode);

  if (cfi.inode in diskFilesSeen) return;
  diskFilesSeen[cfi.inode] = true;
  if (!cfi.isDir) {
    totalDiskSize += cfi.size;
    diskFileList.unsafeArrayAppend(cfi);
    //conwriteln("  FILE!");
    return;
  }

  string[] dirs;
  scope(exit) delete dirs;

  assert(cfi.name[$-1] == '/');
  foreach (Glob.Item it; Glob(cfi.name~"*", GLOB_NOSORT|GLOB_PERIOD|GLOB_TILDE_CHECK|GLOB_MARK)) {
    auto fi = FileInfo(it.name);
    //conwriteln(it.index, ": [", it.name, "] : basename=[", fi.baseName, "]; dirname=[", fi.dirName, "]");
    if (fi.inode in diskFilesSeen) continue;
    if (fi.isDir) {
      auto bname = fi.baseName;
      if (bname == "." || bname == "..") continue;
      dirs.unsafeArrayAppend(fi.name);
      // dir will be marked as visited later
    } else {
      diskFilesSeen[fi.inode] = true;
      totalDiskSize += fi.size;
    }
    if (fi.name.length == 2 && fi.name == "./") assert(0, "internal error");
    if (fi.name.length > 2 && fi.name[0..2] == "./") fi.name = fi.name[2..$];
    diskFileList.unsafeArrayAppend(fi);
  }

  // recurse dirs
  foreach (string dname; dirs) {
    if (dname == "/") continue;
    if (dname[$-1] == '/') dname = dname[0..$-1];
    if (dname.length == 0 || dname == "." || dname == "..") continue;
    scanDisk(dname);
  }
}


void finalizeDiskScan () {
  import std.algorithm : sort;
  diskFileList.sort;
}


// ////////////////////////////////////////////////////////////////////////// //
string n2s (ulong n) {
  string res;
  int left = 3;
  do {
    if (left == 0) { res = ","~res; left = 3; }
    res = cast(char)('0'+n%10)~res;
    --left;
  } while ((n /= 10) != 0);
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
// returns zip file size
ulong packZip (ConString outfname, FileInfo[] flist, ZipWriter.Method pmt) {
  import core.time;
  import std.string : format;
  import std.exception : collectException;
  import std.file : chdir, getcwd, mkdirRecurse, remove, rmdirRecurse;
  import std.path : absolutePath, expandTilde;
  import std.process;

  collectException(outfname.remove());
  auto fo = VFile(outfname.idup.expandTilde.absolutePath, "w");
  auto zw = new ZipWriter(fo);
  scope(failure) {
    if (zw.isOpen) zw.abort();
    fo.close();
    collectException(outfname.remove());
  }
  bool[string] fileseen;
  foreach (immutable flistidx, const ref de; flist) {
    if (de.name in fileseen) continue;
    fileseen[de.name] = true;
    conwrite("  [", n2s(flistidx+1), "/", n2s(flist.length), "] ", de.name, " ... ");
    uint zipidx;
    try {
      if (de.isDir) {
        zipidx = zw.appendDir(de.name, ZipFileTime(de.modtime));
        conwriteln("OK");
      } else {
        ulong origsz = de.size;
        conwrite("  0%");
        int oldprc = 0;
        MonoTime lastProgressTime = MonoTime.currTime;
        // don't ignore case
        zipidx = zw.pack(VFile(de.name, "IZ"), de.name, ZipFileTime(de.modtime), pmt, de.size, delegate (ulong curpos) {
          int prc = (curpos > 0 ? cast(int)(cast(ulong)100*curpos/origsz) : 0);
          if (prc != oldprc) {
            auto stt = MonoTime.currTime;
            if ((stt-lastProgressTime).total!"msecs" >= 1000) {
              lastProgressTime = stt;
              if (prc < 0) prc = 0; else if (prc > 100) prc = 100;
              conwritef!"\x08\x08\x08\x08%3u%%"(cast(uint)prc);
              oldprc = prc;
            } else {
              //conwriteln(curpos, " : ", origsz);
            }
          }
        });
        conwritefln!"\x08\x08\x08\x08[%s] %s -> %s (%s%%)"(zw.files[zipidx].methodName, n2s(de.size), n2s(zw.files[zipidx].pksize),
          (de.size > 0 ? cast(uint)(100UL*zw.files[zipidx].pksize/de.size) : 0), // left from unpacked
        );
        //if (zw.files[zidx].crc != de.stat("crc32").get!uint) throw new Exception("crc error!");
      }
      zw.files[zipidx].unixmode = de.unixmode;
    } catch (Exception e) {
      conwriteln("ERROR: ", e.msg);
      throw e;
    }
  }
  zw.finish();
  return fo.size;
}


// ////////////////////////////////////////////////////////////////////////// //
void main (string[] args) {
  auto method = ZipWriter.Method.Lzma;

  for (usize idx = 1; idx < args.length;) {
    string arg = args[idx];
    if (arg == "--") {
      import std.algorithm : remove;
      args = args.remove(idx);
      break;
    }
    if (arg.length == 0) {
      import std.algorithm : remove;
      args = args.remove(idx);
      continue;
    }
    if (arg[0] == '-') {
      switch (arg) {
        case "--lzma": method = ZipWriter.Method.Lzma; break;
        case "--store": method = ZipWriter.Method.Store; break;
        case "--deflate": method = ZipWriter.Method.Deflate; break;
        default: conwriteln("invalid argument: '", arg, "'"); throw new Exception("boom");
      }
      import std.algorithm : remove;
      args = args.remove(idx);
      continue;
    }
    ++idx;
  }

  conwriteln("using '", method, "' method...");

  if (args.length < 3) assert(0, "arcname?");

  string outfname = args[1];
  if (!outfname.endsWithCI(".zip") && !outfname.endsWithCI(".pk3")) outfname ~= ".zip";

  conwriteln("scanning...");
  foreach (string dpath; args[2..$]) scanDisk(dpath);
  finalizeDiskScan();
  if (diskFileList.length == 0) assert(0, "no files!");
  conwriteln(diskFileList.length, " file", (diskFileList.length != 1 ? "s" : ""), " found, ", n2s(totalDiskSize), " bytes.");

  /*
  foreach (const ref fi; list) {
    import core.stdc.time : localtime, strftime;
    char[1024] buf = void;
    auto tmx = localtime(cast(int*)&fi.modtime);
    auto len = strftime(buf.ptr, buf.length, "%Y/%m/%d %H:%M:%S", tmx);
    conwriteln(fi.name, " [", fi.type, "]  ", fi.size, "  ", buf[0..len]);
  }
  */

  conwriteln("creating '", outfname, "'...");
  ulong fsize = packZip(outfname, diskFileList, method);
  conwritefln!"DONE, TOTALS: %s -> %s %3u%%"(n2s(totalDiskSize), n2s(fsize), (totalDiskSize ? cast(uint)(100*fsize/totalDiskSize) : 100));
}
