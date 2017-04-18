#!/usr/bin/env rdmd
module rezip is aliced;

import std.datetime;

import iv.cmdcon;
import iv.vfs;
import iv.vfs.util;
import iv.vfs.writers.zip;


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


void repackZip (ConString infname, ConString outfname, ZipWriter.Method pmt) {
  import core.time;
  import std.string : format;
  import std.exception : collectException;
  import std.file : chdir, getcwd, mkdirRecurse, remove, rmdirRecurse;
  import std.path : absolutePath, expandTilde;
  import std.process;
  auto pakid = vfsAddPak(infname);
  scope(exit) vfsRemovePak(pakid);
  collectException(outfname.remove());
  auto fo = VFile(outfname.idup.expandTilde.absolutePath, "w");
  auto zw = new ZipWriter(fo);
  scope(failure) {
    if (zw.isOpen) zw.abort();
    fo.close();
    collectException(outfname.remove());
  }
  bool[string] fileseen;
  foreach_reverse (const ref de; vfsFileList) {
    if (de.name in fileseen) continue;
    fileseen[de.name] = true;
    conwrite("  ", de.name, " ... ");
    try {
      auto zidx = zw.pack(VFile(de.name, "I"), de.name, ZipFileTime(de.modtime), pmt, de.size); // don't ignore case
      conwritefln!"[%s] %s -> %s"(zw.files[zidx].methodName, n2s(de.pksize), n2s(zw.files[zidx].pksize));
      if (zw.files[zidx].crc != de.crc32) throw new Exception("crc error!");
    } catch (Exception e) {
      conwriteln("ERROR: ", e.msg);
      throw e;
    }
  }
  zw.finish();
}


void main (string[] args) {
  auto method = ZipWriter.Method.Lzma;

  for (size_t idx = 1; idx < args.length;) {
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

  ulong oldtotal, newtotal;
  foreach (string ifname; args[1..$]) {
    import std.file;
    import std.path;
    auto ofname = ifname~".$$$";
    scope(failure) {
      import std.exception : collectException;
      import std.file : remove;
      ofname.remove();
    }
    conwriteln(":::[ ", ifname, " ]:::");
    SysTime atime, mtime;
    getTimes(ifname, atime, mtime);
    repackZip(ifname, ofname, method);
    import std.file : rename, getSize;
    auto oldsize = ifname.getSize;
    auto newsize = ofname.getSize;
    ofname.rename(ifname);
    setTimes(ifname, atime, mtime);
    conwriteln(" ", n2s(oldsize), " -> ", n2s(newsize));
    oldtotal += oldsize;
    newtotal += newsize;
  }
  conwriteln("TOTAL: ", n2s(oldtotal), " -> ", n2s(newtotal), "  saved: ", (oldtotal < newtotal ? "-" : ""), n2s(oldtotal < newtotal ? newtotal-oldtotal : oldtotal-newtotal));
}
