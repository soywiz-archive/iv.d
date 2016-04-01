/* Invisible Vector Library
 * coded by Ketmar // Invisible Vector <ketmar@ketmar.no-ip.org>
 * Understanding is not required. Only obedience.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
// VFS pathes and data files
module iv.vfs.main;
private:

import iv.vfs : usize;
import iv.vfs.augs;
import iv.vfs.error;
import iv.vfs.vfile;
import iv.vfs.posixci;
import iv.vfs.koi8;
static import core.sync.mutex;


// ////////////////////////////////////////////////////////////////////////// //
shared bool vflagIgnoreCase = true; // ignore file name case by default


/// get "ingore filename case" flag (default: true)
@property bool vfsIgnoreCase () nothrow @trusted @nogc {
  import core.atomic : atomicLoad;
  return atomicLoad(vflagIgnoreCase);
}

/// set "ingore filename case" flag
@property void vfsIgnoreCase (bool v) nothrow @trusted @nogc {
  import core.atomic : atomicStore;
  return atomicStore(vflagIgnoreCase, v);
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared core.sync.mutex.Mutex ptlock;
shared static this () { ptlock = new core.sync.mutex.Mutex; }


// ////////////////////////////////////////////////////////////////////////// //
/// abstract class for VFS drivers
public abstract class VFSDriver {
  /// for dir range
  public static struct DirEntry {
    string name; // for disk: doesn't include base path; ends with '/'
    long size; // can be -1 if size is not known; for dirs means nothing
  }

  /// this constructor is used for disk drivers
  this () {}

  /// this constructor is used for archive drivers.
  /// `prefixpath`: this will be prepended to each name from archive, unmodified.
  this (VFile fl, const(char)[] prefixpath) { throw new VFSException("not implemented for abstract driver"); }

  /// try to find and open the file in archive.
  /// should return `VFile.init` if no file was found.
  /// should not throw (except for VERY unrecoverable error).
  /// doesn't do any security checks, 'cause i don't care.
  abstract VFile tryOpen (const(char)[] fname, bool ignoreCase);

  /// get number of entries in archive directory.
  @property usize dirLength () { return 0; }
  /// get directory entry with the given index. can throw, but it's not necessary.
  DirEntry dirEntry (usize idx) { return DirEntry.init; }
}


/// abstract class for "pak" files
public abstract class VFSDriverDetector {
  /// return null if it can't open the thing.
  /// `prefixpath`: this will be prepended to each name from archive, unmodified.
  abstract VFSDriver tryOpen (VFile fl, const(char)[] prefixpath);
}


// ////////////////////////////////////////////////////////////////////////// //
/// you can register this driver as "last" to prevent disk searches
public final class VFSDriverAlwaysFail : VFSDriver {
  override VFile tryOpen (const(char)[] fname, bool ignoreCase) {
    throw new VFSException("can't open file '"~fname.idup~"'");
  }
}

/// you can register this driver to try disk files with the given data path
public final class VFSDriverDisk : VFSDriver {
private:
  string dataPath;

public:
  this () { dataPath = "./"; }

  this(T) (T dpath) if (is(T : const(char)[])) {
    if (dpath.length == 0) {
      dataPath = "./";
    } else if (dpath[$-1] == '/') {
      static if (is(T == string)) dataPath = dpath; else dataPath = dpath.idup;
    } else {
      dataPath = dpath~"/";
    }
  }

  /// doesn't do any security checks, 'cause i don't care
  override VFile tryOpen (const(char)[] fname, bool ignoreCase) {
    static import core.stdc.stdio;
    if (fname.length == 0) return VFile.init;
    char[2049] nbuf;
    if (fname[0] == '/') {
      if (dataPath[0] != '/' || fname.length <= dataPath.length) {
        bool hit = (ignoreCase ? koi8StrCaseEqu(fname[0..dataPath.length], dataPath) : fname[0..dataPath.length] == dataPath);
        if (!hit) return VFile.init;
      }
      if (fname.length > 2048) return VFile.init;
      nbuf[0..fname.length] = fname[];
      nbuf[fname.length] = '\0';
    } else {
      if (fname.length+dataPath.length < fname.length || fname.length+dataPath.length > 2048) return VFile.init;
      nbuf[0..dataPath.length] = dataPath[];
      nbuf[dataPath.length..dataPath.length+fname.length] = fname[];
      nbuf[dataPath.length+fname.length] = '\0';
    }
    if (ignoreCase) {
      uint len;
      while (len < nbuf.length && nbuf.ptr[len]) ++len;
      auto pt = findPathCI(nbuf[0..len]);
      if (pt is null) return VFile.init;
      nbuf[pt.length] = '\0';
    }
    auto fl = core.stdc.stdio.fopen(nbuf.ptr, "rb");
    if (fl is null) return VFile.init;
    try { return VFile(fl); } catch (Exception e) {}
    core.stdc.stdio.fclose(fl);
    return VFile.init;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct DriverInfo {
  enum Mode { Normal, First, Last }
  Mode mode;
  VFSDriver drv;
}

__gshared DriverInfo[] drivers;


// ////////////////////////////////////////////////////////////////////////// //
/// register new VFS driver
public void vfsRegister(string mode="normal") (VFSDriver drv) {
  import core.atomic : atomicOp;
  static assert(mode == "normal" || mode == "last" || mode == "first");
  if (drv is null) return;
  //{ import core.stdc.stdio : printf; printf("*** %p [%s]\n", cast(void*)drv, mode.ptr); }
  ptlock.lock();
  scope(exit) ptlock.unlock();
  static if (mode == "normal") {
    // normal
    usize ipos = drivers.length;
    while (ipos > 0 && drivers[ipos-1].mode == DriverInfo.Mode.First) --ipos;
    //{ import core.stdc.stdio : printf; printf("  : %u (%u)\n", cast(uint)ipos, cast(uint)drivers.length); }
    if (ipos == drivers.length) {
      drivers ~= DriverInfo(DriverInfo.Mode.Normal, drv);
    } else {
      drivers.length += 1;
      foreach_reverse (immutable c; ipos+1..drivers.length) drivers[c] = drivers[c-1];
      drivers[ipos] = DriverInfo(DriverInfo.Mode.Normal, drv);
    }
  } else static if (mode == "first") {
    // first
    drivers ~= DriverInfo(DriverInfo.Mode.First, drv);
  } else static if (mode == "last") {
    drivers = [DriverInfo(DriverInfo.Mode.Last, drv)]~drivers;
  } else {
    static assert(0, "wtf?!");
  }
  /*
  {
    foreach (immutable idx, ref di; drivers) {
      import core.stdc.stdio : printf;
      printf("+++ %u (%u) %p\n", cast(uint)idx, cast(uint)di.mode, cast(void*)di.drv);
    }
  }
  */
}


// ////////////////////////////////////////////////////////////////////////// //
/// list all files known to VFS.
/// WARNING: don't add new drivers while this is in process!
public VFSDriver.DirEntry[] vfsFileList () {
  usize[string] filesSeen;
  VFSDriver.DirEntry[] res;

  ptlock.lock();
  scope(exit) ptlock.unlock();

  foreach (ref drvnfo; drivers) {
    foreach (immutable idx; 0..drvnfo.drv.dirLength) {
      auto de = drvnfo.drv.dirEntry(idx);
      if (de.name.length == 0) continue;
      if (auto iptr = de.name in filesSeen) {
        res.ptr[*iptr] = de;
      } else {
        filesSeen[de.name] = res.length;
        res ~= de;
      }
    }
  }

  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
public VFile vfsOpenFile (const(char)[] fname) {
  static import core.stdc.stdio;

  void error (string msg, Throwable e=null, string file=__FILE__, usize line=__LINE__) { throw new VFSException(msg, file, line, e); }

  void errorfn (const(char)[] msg, Throwable e=null, string file=__FILE__, usize line=__LINE__) {
    import std.array : appender;
    auto s = appender!string();
    foreach (char ch; msg) {
      if (ch == '!') s.put(fname); else s.put(ch);
    }
    throw new VFSException(s.data, file, line, e);
  }

  if (fname.length == 0) error("can't open file ''");

  bool ignoreCase = vfsIgnoreCase;
  {
    ptlock.lock();
    scope(exit) ptlock.unlock();

    // try all drivers
    foreach_reverse (ref di; drivers) {
      try {
        auto fl = di.drv.tryOpen(fname, ignoreCase);
        if (fl.isOpen) return fl;
      } catch (Exception e) {
        // chain
        errorfn("can't open file '!'", e);
      }
    }
  }

  // no drivers found, try disk file
  return vfsDiskOpen(fname, (ignoreCase ? "ri" : "rI"));
}


// ////////////////////////////////////////////////////////////////////////// //
struct DetectorInfo {
  enum Mode { Normal, First, Last }
  Mode mode;
  VFSDriverDetector dt;
}

__gshared DetectorInfo[] detectors;


public void vfsRegisterDetector(string mode="normal") (VFSDriverDetector dt) {
  static assert(mode == "normal" || mode == "last" || mode == "first");
  if (dt is null) return;
  ptlock.lock();
  scope(exit) ptlock.unlock();
  static if (mode == "normal") {
    // normal
    usize ipos = detectors.length;
    while (ipos > 0 && detectors[ipos-1].mode == DetectorInfo.Mode.Last) --ipos;
    if (ipos == detectors.length) {
      detectors ~= DetectorInfo(DetectorInfo.Mode.Normal, dt);
    } else {
      detectors.length += 1;
      foreach_reverse (immutable c; ipos+1..detectors.length) detectors[c] = detectors[c-1];
      detectors[ipos] = DetectorInfo(DetectorInfo.Mode.Normal, dt);
    }
  } else static if (mode == "last") {
    detectors ~= DetectorInfo(DetectorInfo.Mode.First, dt);
  } else static if (mode == "first") {
    detectors = [DetectorInfo(DetectorInfo.Mode.Last, dt)]~detectors;
  } else {
    static assert(0, "wtf?!");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// `prefixpath`: this will be prepended to each name from archive, unmodified.
public void vfsAddPak (const(char)[] fname, const(char)[] prefixpath=null) {
  vfsAddPak(vfsDiskOpen(fname), fname, prefixpath);
}


/// `prefixpath`: this will be prepended to each name from archive, unmodified.
public void vfsAddPak(T) (VFile fl, T fname=null, const(char)[] prefixpath=null) if (is(T : const(char)[])) {
  void error (Throwable e=null, string file=__FILE__, usize line=__LINE__) {
    if (fname.length == 0) {
      throw new VFSException("can't open pak file", file, line, e);
    } else {
      import std.array : appender;
      auto s = appender!string();
      s.put("can't open pak file '");
      s.put(fname);
      s.put("'");
      throw new VFSException(s.data, file, line, e);
    }
  }

  if (!fl.isOpen) error();

  ptlock.lock();
  scope(exit) ptlock.unlock();

  // try all detectors
  foreach (ref di; detectors) {
    try {
      fl.seek(0);
      auto drv = di.dt.tryOpen(fl, prefixpath);
      if (drv !is null) { vfsRegister(drv); return; }
    } catch (Exception e) {
      // chain
      error(e);
    }
  }
  error();
}


// ////////////////////////////////////////////////////////////////////////// //
/// takes into account `vfsIgnoreCase` flag. you can override it with 'i' (on) or 'I' (off) mode letter.
public VFile vfsDiskOpen (const(char)[] fname, const(char)[] mode=null) {
  static import core.stdc.stdio;
  if (fname.length == 0) throw new VFSException("can't open file ''");
  if (fname.length > 2048) throw new VFSException("can't open file '"~fname.idup~"'");
  bool[128] got;
  char[16] modebuf;
  uint mpos;
  bool ignoreCase = vfsIgnoreCase;
  foreach (char ch; mode) {
    if (ch < 128 && !got[ch]) {
      if (ch == 'i') { ignoreCase = true; continue; }
      if (ch == 'I') { ignoreCase = false; continue; }
      if (mpos >= modebuf.length-1) throw new VFSException("can't open file '"~fname.idup~"' with mode '"~mode.idup~"'");
      got[ch] = true;
      modebuf.ptr[mpos++] = ch;
      if (!got['b'] && (ch == 'r' || ch == 'w' || ch == 'a' || ch == 'R' || ch == 'W' || ch == 'A')) {
        if (mpos >= modebuf.length-1) throw new VFSException("can't open file '"~fname.idup~"' with mode '"~mode.idup~"'");
        got['b'] = true;
        modebuf.ptr[mpos++] = 'b';
      }
    }
  }
  if (mpos == 0) {
    modebuf[0..3] = "rb\0";
  } else {
    modebuf[mpos++] = '\0';
  }
  char[2049] nbuf;
  nbuf[0..fname.length] = fname[];
  nbuf[fname.length] = '\0';
  if (ignoreCase) {
    // we have to lock here, as `findPathCI()` is not thread-safe
    ptlock.lock();
    scope(exit) ptlock.unlock();
    auto pt = findPathCI(nbuf[0..fname.length]);
    if (pt is null) {
      // restore filename for correct error message
      nbuf[0..fname.length] = fname[];
      nbuf[fname.length] = '\0';
    } else {
      nbuf[pt.length] = '\0';
    }
  }
  auto fl = core.stdc.stdio.fopen(nbuf.ptr, modebuf.ptr);
  if (fl is null) throw new VFSException("can't open file '"~fname.idup~"'");
  scope(failure) core.stdc.stdio.fclose(fl); // just in case
  try {
    return VFile(fl);
  } catch (Exception e) {
    // chain
    throw new VFSException("can't open file '"~fname.idup~"'", __FILE__, __LINE__, e);
  }
}
