#!/usr/bin/env rdmd
module rezip /*is aliced*/;

import iv.alice;
import iv.cmdcon;
import iv.vfs;
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


void repackZip (string infname, string outfname) {
  import core.time;
  import std.string : format;
  import std.exception : collectException;
  import std.file : chdir, getcwd, mkdirRecurse, remove, rmdirRecurse;
  import std.path : expandTilde;
  import std.process;
  auto pakid = vfsAddPak(infname.expandTilde);
  scope(exit) vfsRemovePak(pakid);
  outfname = outfname.expandTilde;
  collectException(outfname.remove());
  auto fo = VFile(outfname, "w");
  auto zw = new ZipWriter(fo);
  scope(failure) if (zw.isOpen) zw.abort();
  bool[string] fileseen;
  foreach_reverse (const ref de; vfsFileList) {
    if (de.name in fileseen) continue;
    fileseen[de.name] = true;
    conwrite("  ", de.name, " ... ");
    try {
      auto fl = VFile(de.name);
      auto zidx = zw.pack(fl, de.name, zw.Method.Lzma);
      if (zw.files[zidx].crc != de.crc32) throw new Exception("crc error!");
      conwriteln("OK");
    } catch (Exception e) {
      conwriteln("ERROR: ", e.msg);
      throw e;
    }
  }
  zw.finish();
}


void main (string[] args) {
  ulong oldtotal, newtotal;
  foreach (string ifname; args[1..$]) {
    import std.path;
    auto ofname = ifname~".$$$";
    scope(failure) {
      import std.exception : collectException;
      import std.file : remove;
      ofname.remove();
    }
    conwriteln(":::[ ", ifname, " ]:::");
    repackZip(ifname, ofname);
    import std.file : rename, getSize;
    auto oldsize = ifname.getSize;
    auto newsize = ofname.getSize;
    ofname.rename(ifname);
    conwriteln(" ", n2s(oldsize), " -> ", n2s(newsize));
    oldtotal += oldsize;
    newtotal += newsize;
  }
  conwriteln("TOTAL: ", n2s(oldtotal), " -> ", n2s(newtotal), "  saved: ", (oldtotal < newtotal ? "-" : ""), n2s(oldtotal < newtotal ? newtotal-oldtotal : oldtotal-newtotal));
}
