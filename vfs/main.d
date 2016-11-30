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

import core.time;
import iv.vfs.types : usize;
import iv.vfs.config;
import iv.vfs.augs;
import iv.vfs.error;
import iv.vfs.vfile;
import iv.vfs.posixci;
import iv.vfs.koi8;
static import core.sync.mutex;


// ////////////////////////////////////////////////////////////////////////// //
private shared int vfsLockedFlag = 0; // !0: can't add/remove drivers
shared bool vflagIgnoreCase = true; // ignore file name case
shared bool vflagIgnoreCaseNoDat = false; // ignore file name case when no archive files are connected


/// get "ingore filename case" flag (default: true)
@property bool vfsIgnoreCase () nothrow @trusted @nogc { import core.atomic : atomicLoad; return atomicLoad(vflagIgnoreCase); }

/// set "ingore filename case" flag
@property void vfsIgnoreCase (bool v) nothrow @trusted @nogc { import core.atomic : atomicStore; return atomicStore(vflagIgnoreCase, v); }

/// get "ingore filename case" flag when no archive files are attached (default: false)
@property bool vfsIgnoreCaseNoDat () nothrow @trusted @nogc { import core.atomic : atomicLoad; return atomicLoad(vflagIgnoreCaseNoDat); }

/// set "ingore filename case" flag when no archive files are attached
@property void vfsIgnoreCaseNoDat (bool v) nothrow @trusted @nogc { import core.atomic : atomicStore; return atomicStore(vflagIgnoreCaseNoDat, v); }


// ////////////////////////////////////////////////////////////////////////// //
__gshared core.sync.mutex.Mutex ptlock;
shared static this () { ptlock = new core.sync.mutex.Mutex; }

// non-empty msg: check lockflag
private struct VFSLock {
  int locked = 0;

  @disable this (this);

  ~this () {
    if (locked) {
      import core.atomic;
      if (locked < 0) assert(0, "vfs: internal error");
      atomicOp!"-="(vfsLockedFlag, 1);
      ptlock.unlock();
      locked = -1;
    }
  }

  static VFSLock lock (string msg=null) {
    import core.atomic;
    ptlock.lock();
    if (msg.length) {
      if (atomicLoad(vfsLockedFlag)) {
        ptlock.unlock();
        throw new VFSException(msg);
      }
    }
    VFSLock lk;
    lk.locked = 1;
    atomicOp!"+="(vfsLockedFlag, 1);
    return lk;
  }
}


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
public class VFSDriverDisk : VFSDriver {
protected:
  string dataPath;

public:
  this () { dataPath = "./"; }

  this(T : const(char)[]) (T dpath) {
    static if (is(T == typeof(null))) {
      dataPath = "./";
    } else {
      if (dpath.length == 0) {
        dataPath = "./";
      } else if (dpath[$-1] == '/') {
        static if (is(T == string)) dataPath = dpath; else dataPath = dpath.idup;
      } else {
        dataPath = dpath~"/";
      }
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
    static if (VFS_NORMAL_OS) if (ignoreCase) {
      uint len;
      while (len < nbuf.length && nbuf.ptr[len]) ++len;
      auto pt = findPathCI(nbuf[0..len]);
      if (pt is null) return VFile.init;
      nbuf[pt.length] = '\0';
    }
    static if (VFS_NORMAL_OS) {
      auto fl = core.stdc.stdio.fopen(nbuf.ptr, "r");
    } else {
      auto fl = core.stdc.stdio.fopen(nbuf.ptr, "rb");
    }
    if (fl is null) return VFile.init;
    try { return VFile(fl); } catch (Exception e) {}
    core.stdc.stdio.fclose(fl);
    return VFile.init;
  }
}

/// same as `VFSDriverDisk`, but provides file list too
public class VFSDriverDiskListed : VFSDriverDisk {
protected:
  DirEntry[] files;
  bool flistInited;

protected:
  final void buildFileList () {
    import std.file : DE = DirEntry, dirEntries, SpanMode;
    if (flistInited) return;
    try {
      foreach (DE de; dirEntries(dataPath, SpanMode./*breadth*/depth)) {
        if (!de.isFile) continue;
        if (de.name.length <= dataPath.length) continue;
        files ~= DirEntry(de.name[dataPath.length..$], de.size);
      }
    } catch (Exception e) {}
    flistInited = true;
  }

public:
  this () { super(); }
  this(T : const(char)[]) (T dpath) { super(dpath); }

  /// get number of entries in archive directory.
  override @property usize dirLength () { buildFileList(); return files.length; }
  /// get directory entry with the given index. can throw, but it's not necessary.
  override DirEntry dirEntry (usize idx) { buildFileList(); return files[idx]; }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct VFSDriverId {
private:
  uint id;
  static VFSDriverId create () nothrow @trusted @nogc { pragma(inline, true); return VFSDriverId(++lastIdNumber); }

  public bool opCast(T) () const pure nothrow @safe @nogc if (is(T == bool)) { pragma(inline, true); return (id != 0); }
  public @property bool valid () const pure nothrow @safe @nogc { pragma(inline, true); return (id != 0); }
  public bool opEquals() (const VFSDriverId b) const pure nothrow @safe @nogc { pragma(inline, true); return (id == b.id); }

private:
  __gshared uint lastIdNumber;
}

struct DriverInfo {
  enum Mode { Normal, First, Last }
  Mode mode;
  VFSDriver drv;
  string fname;
  string prefixpath;
  VFSDriverId drvid;
  bool temp; // temporary? will not be used in listing, and eventually removed
  MonoTime tempUsedTime; // last used time for temp paks

  this (Mode amode, VFSDriver adrv, string afname, string apfxpath, VFSDriverId adid, bool atemp) {
    mode = amode;
    drv = adrv;
    fname = afname;
    prefixpath = apfxpath;
    drvid = adid;
    temp = atemp;
    if (atemp) tempUsedTime = MonoTime.currTime;
  }
}

__gshared DriverInfo[] drivers;
__gshared uint tempDrvCount = 0;

private void cleanupDrivers () {
  if (tempDrvCount == 0) return;
  bool ctValid = false;
  MonoTime ct;
  auto idx = drivers.length;
  while (idx > 0) {
    --idx;
    if (!drivers.ptr[idx].temp) continue;
    if (!ctValid) { ct = MonoTime.currTime; ctValid = true; }
    if ((ct-drivers.ptr[idx].tempUsedTime).total!"seconds" >= 5) {
      // remove it
      --tempDrvCount;
      foreach (immutable c; idx+1..drivers.length) drivers.ptr[c-1] = drivers.ptr[c];
      drivers.length -= 1;
      drivers.assumeSafeAppend;
      if (idx == 0 || tempDrvCount == 0) return;
      --idx;
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// register new VFS driver
/// driver order is: firsts, normals, lasts (obviously ;-).
/// search order is from first to last, in reverse order.
/// you can use returned driver id to unregister the driver later.
public VFSDriverId vfsRegister(string mode="normal", bool temp=false) (VFSDriver drv, const(char)[] fname=null, const(char)[] prefixpath=null) {
  static assert(mode == "normal" || mode == "last" || mode == "first");
  import core.atomic : atomicOp;
  if (drv is null) return VFSDriverId.init;
  auto lock = VFSLock.lock("can't register drivers in list operations");
  cleanupDrivers();
  VFSDriverId did = VFSDriverId.create;
  static if (temp) ++tempDrvCount;
  static if (mode == "normal") {
    // normal
    usize ipos = drivers.length;
    while (ipos > 0 && drivers[ipos-1].mode == DriverInfo.Mode.First) --ipos;
    if (ipos == drivers.length) {
      drivers ~= DriverInfo(DriverInfo.Mode.Normal, drv, fname.idup, prefixpath.idup, did, temp);
    } else {
      drivers.length += 1;
      foreach_reverse (immutable c; ipos+1..drivers.length) drivers[c] = drivers[c-1];
      drivers[ipos] = DriverInfo(DriverInfo.Mode.Normal, drv, fname.idup, prefixpath.idup, did, temp);
    }
  } else static if (mode == "first") {
    // first
    drivers ~= DriverInfo(DriverInfo.Mode.First, drv, fname.idup, prefixpath.idup, did, temp);
  } else static if (mode == "last") {
    drivers = [DriverInfo(DriverInfo.Mode.Last, drv, fname.idup, prefixpath.idup, did, temp)]~drivers;
  } else {
    static assert(0, "wtf?!");
  }
  return did;
}


// ////////////////////////////////////////////////////////////////////////// //
/// find driver. returns invalid VFSDriverId if the driver was not found.
/// WARNING: don't add new drivers while this is in process!
public VFSDriverId vfsFindDriver (const(char)[] fname, const(char)[] prefixpath=null) {
  auto lock = VFSLock.lock();
  foreach_reverse (immutable idx, ref drv; drivers) {
    if (!drv.temp && drv.fname == fname && drv.prefixpath == prefixpath) return drv.drvid;
  }
  return VFSDriverId.init;
}


// ////////////////////////////////////////////////////////////////////////// //
/// unregister driver
/// WARNING: don't add new drivers while this is in process!
public bool vfsUnregister (VFSDriverId id) {
  auto lock = VFSLock.lock("can't unregister drivers in list operations");
  cleanupDrivers();
  foreach_reverse (immutable idx, ref drv; drivers) {
    if (drv.drvid == id) {
      // i found her!
      foreach (immutable c; idx+1..drivers.length) drivers[c-1] = drivers[c];
      drivers.length -= 1;
      drivers.assumeSafeAppend;
      return true;
    }
  }
  return false;
}


// ////////////////////////////////////////////////////////////////////////// //
/// list all files known to VFS.
/// WARNING: don't add new drivers while this is in process!
public VFSDriver.DirEntry[] vfsFileList () {
  usize[string] filesSeen;
  VFSDriver.DirEntry[] res;

  auto lock = VFSLock.lock();
  cleanupDrivers();
  foreach_reverse (ref drvnfo; drivers) {
    if (drvnfo.temp) continue;
    foreach_reverse (immutable idx; 0..drvnfo.drv.dirLength) {
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

/// ditto.
public alias vfsAllFiles = vfsFileList;


/// call callback for each known file in VFS. return non-zero from callback to stop.
/// WARNING: don't add new drivers while this is in process!
public int vfsForEachFile (scope int delegate (in ref VFSDriver.DirEntry de) cb) {
  if (cb is null) return 0;

  auto lock = VFSLock.lock();
  cleanupDrivers();
  bool[string] filesSeen;
  foreach_reverse (ref drvnfo; drivers) {
    if (drvnfo.temp) continue;
    foreach_reverse (immutable idx; 0..drvnfo.drv.dirLength) {
      auto de = drvnfo.drv.dirEntry(idx);
      if (de.name !in filesSeen) {
        filesSeen[de.name] = true;
        if (auto res = cb(de)) return res;
      }
    }
  }
  return 0;
}


/// call callback for each known file in VFS. return non-zero from callback to stop.
/// WARNING: don't add new drivers while this is in process!
public int vfsForEachFile (scope int delegate (in ref VFSDriver.DirEntry de, VFSDriverId drvid) cb) {
  if (cb is null) return 0;

  auto lock = VFSLock.lock();
  cleanupDrivers();
  bool[string] filesSeen;
  foreach_reverse (ref drvnfo; drivers) {
    if (drvnfo.temp) continue;
    foreach_reverse (immutable idx; 0..drvnfo.drv.dirLength) {
      auto de = drvnfo.drv.dirEntry(idx);
      if (de.name !in filesSeen) {
        filesSeen[de.name] = true;
        if (auto res = cb(de, drvnfo.drvid)) return res;
      }
    }
  }
  return 0;
}


/// Ditto.
public void vfsForEachFile (scope void delegate (in ref VFSDriver.DirEntry de, VFSDriverId drvid) cb) {
  if (cb !is null) vfsForEachFile((in ref VFSDriver.DirEntry de, VFSDriverId drvid) { cb(de, drvid); return 0; });
}


// ////////////////////////////////////////////////////////////////////////// //
char[] buildModeBuf (char[] modebuf, const(char)[] mode, ref bool ignoreCase) {
  bool[128] got;
  uint mpos;
  ignoreCase = (drivers.length ? vfsIgnoreCase : vfsIgnoreCaseNoDat);
  foreach (char ch; mode) {
    if (ch < 128 && !got[ch]) {
      if (ch == 'i') { ignoreCase = true; continue; }
      if (ch == 'I') { ignoreCase = false; continue; }
      static if (VFS_NORMAL_OS) if (ch == 'b'/* || ch == 't'*/) continue;
      if (mpos >= modebuf.length-1) throw new VFSException("invalid mode '"~mode.idup~"' (too long)");
      got[ch] = true;
      modebuf.ptr[mpos++] = ch;
    }
  }
  // add 'b' for idiotic shitdoze
  static if (!VFS_NORMAL_OS) {
    if (!got['b'] && !got['t'] && (got['r'] || got['w'] || got['a'] || got['R'] || got['W'] || got['A'])) {
      if (mpos >= modebuf.length-1) throw new VFSException("invalid mode '"~mode.idup~"' (too long)");
      modebuf.ptr[mpos++] = 'b';
    }
  }
  if (mpos == 0) {
    if (modebuf.length < 2) throw new VFSException("invalid mode '"~mode.idup~"' (too long)");
    static if (VFS_NORMAL_OS) {
      modebuf[0..1] = "r";
      mpos = 1;
    } else {
      modebuf[0..2] = "rb";
      mpos = 2;
    }
  }
  if (modebuf.length-mpos < 1) throw new VFSException("invalid mode '"~mode.idup~"' (too long)");
  modebuf[mpos++] = '\0';
  return modebuf[0..mpos];
}


// ////////////////////////////////////////////////////////////////////////// //
bool isROMode (char[] modebuf) {
  foreach (char ch; modebuf) {
    if (ch == 'w' || ch == 'W' || ch == 'a' || ch == 'A' || ch == '+' || ch == 't') return false;
  }
  return true;
}


public VFile vfsOpenFile(T:const(char)[], bool usefname=true) (T fname, const(char)[] mode=null) {
  static import core.stdc.stdio;

  void error (string msg, Throwable e=null, string file=__FILE__, usize line=__LINE__) { throw new VFSException(msg, file, line, e); }

  void errorfn(T:const(char)[]) (T msg, Throwable e=null, string file=__FILE__, usize line=__LINE__) {
    static assert(!is(T == typeof(null)), "wtf?!");
    import std.array : appender;
    foreach (char cc; msg) {
      if (cc == '!') {
        auto s = appender!string();
        foreach (char ch; msg) {
          if (ch == '!') {
            foreach (char xch; fname) s.put(xch);
          } else {
            s.put(ch);
          }
        }
        throw new VFSException(s.data, file, line, e);
      }
    }
    throw new VFSException(msg, file, line, e);
  }

  static if (is(T == typeof(null))) {
    error("can't open file ''");
  } else {
    if (fname.length == 0) error("can't open file ''");

    bool ignoreCase;
    char[16] modebuf = 0;
    auto mdb = buildModeBuf(modebuf[], mode, ignoreCase);

    {
      auto lock = VFSLock.lock();
      cleanupDrivers();
      // try all drivers
      foreach_reverse (ref di; drivers) {
        try {
          auto fl = di.drv.tryOpen(fname, ignoreCase);
          if (fl.isOpen) {
            if (di.temp) di.tempUsedTime = MonoTime.currTime;
            if (!isROMode(mdb)) errorfn("can't open file '!' in non-binary non-readonly mode");
            return fl;
          }
        } catch (Exception e) {
          // chain
          errorfn("can't open file '!'", e);
        }
      }
    }

    // no drivers found, try disk file
    return vfsDiskOpen!(T, usefname)(fname, mode);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct DetectorInfo {
  enum Mode { Normal, First, Last }
  Mode mode;
  VFSDriverDetector dt;
}

__gshared DetectorInfo[] detectors;


// ////////////////////////////////////////////////////////////////////////// //
/// register pak (archive) format detector.
public void vfsRegisterDetector(string mode="normal") (VFSDriverDetector dt) {
  static assert(mode == "normal" || mode == "last" || mode == "first");
  if (dt is null) return;
  auto lock = VFSLock.lock("can't register drivers in list operations");
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
public VFSDriverId vfsAddPak(string mode="normal", bool temp=false) (const(char)[] fname, const(char)[] prefixpath=null) {
  foreach (char ch; fname) {
    if (ch == ':') {
      try {
        return vfsAddPak!(mode, temp)(vfsOpenFile(fname), fname, prefixpath);
      } catch (Exception) {}
      return vfsAddPak!(mode, temp)(vfsDiskOpen(fname), fname, prefixpath);
    }
  }
  try {
    return vfsAddPak!(mode, temp)(vfsDiskOpen(fname), fname, prefixpath);
  } catch (Exception) {}
  return vfsAddPak!(mode, temp)(vfsOpenFile(fname), fname, prefixpath);
}


/// `prefixpath`: this was be prepended to each name from archive.
public VFSDriverId vfsFindPack (const(char)[] fname, const(char)[] prefixpath=null) {
  return vfsFindDriver(fname, prefixpath);
}


/// `prefixpath`: this was be prepended to each name from archive.
public bool vfsRemovePack (VFSDriverId id) {
  return vfsUnregister(id);
}


/// `prefixpath`: this will be prepended to each name from archive, unmodified.
public VFSDriverId vfsAddPak(string mode="normal", bool temp=false, T : const(char)[]) (VFile fl, T fname="", const(char)[] prefixpath=null) {
  static assert(mode == "normal" || mode == "last" || mode == "first");
  static if (is(T == typeof(null))) {
    return vfsAddPak!(mode, temp, T)(fl, "", prefixpath);
  } else {
    void error (Throwable e=null, string file=__FILE__, usize line=__LINE__) {
      if (fname.length == 0) {
        throw new VFSException("can't open pak file", file, line, e);
      } else {
        import std.format : format;
        throw new VFSException("can't open pak file '%s'".format(fname), file, line, e);
      }
    }

    if (!fl.isOpen) error();

    auto lock = VFSLock.lock("can't register drivers in list operations");
    // try all detectors
    foreach (ref di; detectors) {
      try {
        fl.seek(0);
        auto drv = di.dt.tryOpen(fl, prefixpath);
        if (drv !is null) {
          // hack!
          import core.atomic;
          atomicOp!"-="(vfsLockedFlag, 1);
          scope(exit) atomicOp!"+="(vfsLockedFlag, 1);
          return vfsRegister!(mode, temp)(drv, fname, prefixpath);
        }
      } catch (Exception e) {
        // chain
        error(e);
      }
    }
    error();
    assert(0);
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// takes into account `vfsIgnoreCase` flag. you can override it with 'i' (on) or 'I' (off) mode letter.
public VFile vfsDiskOpen(T:const(char)[], bool usefname=true) (T fname, const(char)[] mode=null) {
  static import core.stdc.stdio;
  static if (is(T == typeof(null))) {
    throw new VFSException("can't open file ''");
  } else {
    if (fname.length == 0) throw new VFSException("can't open file ''");
    if (fname.length > 2048) throw new VFSException("can't open file '"~fname.idup~"'");
    bool ignoreCase;
    char[16] modebuf;
    auto mdb = buildModeBuf(modebuf[], mode, ignoreCase);
    char[2049] nbuf;
    nbuf[0..fname.length] = fname[];
    nbuf[fname.length] = '\0';
    static if (VFS_NORMAL_OS) if (ignoreCase) {
      // we have to lock here, as `findPathCI()` is not thread-safe
      auto lock = VFSLock.lock();
      auto pt = findPathCI(nbuf[0..fname.length]);
      if (pt is null) {
        // restore filename for correct error message
        nbuf[0..fname.length] = fname[];
        nbuf[fname.length] = '\0';
      } else {
        nbuf[pt.length] = '\0';
      }
    }
    auto fl = core.stdc.stdio.fopen(nbuf.ptr, mdb.ptr);
    if (fl is null) throw new VFSException("can't open file '"~fname.idup~"'");
    scope(failure) core.stdc.stdio.fclose(fl); // just in case
    try {
      static if (usefname) {
        static if (is(T == string)) return VFile(fl, fname); else return VFile(fl, fname.idup);
      } else {
        return VFile(fl);
      }
    } catch (Exception e) {
      // chain
      throw new VFSException("can't open file '"~fname.idup~"'", __FILE__, __LINE__, e);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/// open VFile with the given name. supports "file.pak:file1.pak:file.ext" pathes.
public VFile openFileEx (const(char)[] name) {
  if (name.length >= int.max/4) throw new VFSException("name too long");

  // check if name has any prefix at all
  int pfxend = cast(int)name.length;
  while (pfxend > 0 && name.ptr[pfxend-1] != ':') --pfxend;
  if (pfxend == 0) return VFile(name); // easy case

  auto lock = VFSLock.lock();

  // cpos: after last succesfull prefix
  VFile openit (int cpos) {
    while (cpos < name.length) {
      auto ep = cpos;
      while (ep < name.length && name.ptr[ep] != ':') ++ep;
      if (ep >= name.length) return VFile(name);
      if (name.length-ep == 1) throw new VFSException("can't open file '"~name.idup~"'");
      {
        // hack!
        import core.atomic;
        atomicOp!"-="(vfsLockedFlag, 1);
        scope(exit) atomicOp!"+="(vfsLockedFlag, 1);
        vfsAddPak!("normal", true)(name[0..ep], name[0..ep+1]);
      }
      cpos = ep+1;
    }
    throw new VFSException("can't open file '"~name.idup~"'"); // just in case
  }

  // try to find the longest prefix which already exists
  while (pfxend > 0) {
    foreach (ref di; drivers) {
      if (di.prefixpath == name[0..pfxend]) {
        // i found her!
        if (di.temp) di.tempUsedTime = MonoTime.currTime;
        return openit(pfxend);
      }
    }
    --pfxend;
    while (pfxend > 0 && name.ptr[pfxend-1] != ':') --pfxend;
  }
  return openit(0);
}
