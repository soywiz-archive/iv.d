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
static import core.sync.mutex;


// ////////////////////////////////////////////////////////////////////////// //
__gshared core.sync.mutex.Mutex ptlock;
shared static this () { ptlock = new core.sync.mutex.Mutex; }


// ////////////////////////////////////////////////////////////////////////// //
/// abstract class for VFS drivers
public abstract class VFSDriver {
  // return empty VFile if it can't open the thing
  abstract VFile tryOpen (const(char)[] fname);
}

/// abstract class for "pak" files
public abstract class VFSDriverDetector {
  // return null if it can't open the thing
  abstract VFSDriver tryOpen (VFile fl);
}


// ////////////////////////////////////////////////////////////////////////// //
/// you can register this driver as "last" to prevent disk searches
public final class VFSDriverAlwaysFail : VFSDriver {
  override VFile tryOpen (const(char)[] fname) {
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
  override VFile tryOpen (const(char)[] fname) {
    static import core.stdc.stdio;
    if (fname.length == 0) return VFile.init;
    char[2049] nbuf;
    if (fname[0] == '/') {
      if (dataPath[0] != '/' || fname.length <= dataPath.length || fname[0..dataPath.length] != dataPath) return VFile.init;
      if (fname.length > 2048) return VFile.init;
      nbuf[0..fname.length] = fname[];
      nbuf[fname.length] = '\0';
    } else {
      if (fname.length+dataPath.length < fname.length || fname.length+dataPath.length > 2048) return VFile.init;
      nbuf[0..dataPath.length] = dataPath[];
      nbuf[dataPath.length..dataPath.length+fname.length] = fname[];
      nbuf[dataPath.length+fname.length] = '\0';
    }
    auto fl = core.stdc.stdio.fopen(nbuf.ptr, "rb");
    if (fl is null) return VFile.init;
    try { return VFile(fl); } catch (Exception e) {}
    core.stdc.stdio.fclose(fl);
    return VFile.init;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared VFSDriver[] drivers;


// ////////////////////////////////////////////////////////////////////////// //
/// register new VFS driver
public void vfsRegister(string mode="normal") (VFSDriver drv) {
  static assert(mode == "normal" || mode == "last");
  if (drv is null) return;
  ptlock.lock();
  scope(exit) ptlock.unlock();
  static if (mode == "normal") {
    drivers ~= drv;
  } else {
    drivers = [drv]~drivers;
  }
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

  {
    ptlock.lock();
    scope(exit) ptlock.unlock();

    // try all drivers
    foreach_reverse (VFSDriver drv; drivers) {
      try {
        auto fl = drv.tryOpen(fname);
        if (fl.isOpen) return fl;
      } catch (Exception e) {
        // chain
        errorfn("can't open file '!'", e);
      }
    }
  }

  // no drivers found, try disk file
  if (fname.length > 2048) errorfn("can't open file '!'");

  char[2049] nbuf;
  nbuf[0..fname.length] = fname[];
  nbuf[fname.length] = '\0';
  auto fl = core.stdc.stdio.fopen(nbuf.ptr, "rb");
  if (fl is null) errorfn("can't open file '!'");
  scope(failure) core.stdc.stdio.fclose(fl); // just in case
  try {
    return VFile(fl);
  } catch (Exception e) {
    // chain
    errorfn("can't open file '!'", e);
  }
  assert(0);
}


// ////////////////////////////////////////////////////////////////////////// //
__gshared VFSDriverDetector[] detectors;


public void vfsRegisterDetector(string mode="normal") (VFSDriverDetector dt) {
  static assert(mode == "normal" || mode == "first");
  if (dt is null) return;
  ptlock.lock();
  scope(exit) ptlock.unlock();
  static if (mode == "normal") {
    detectors ~= drv;
  } else {
    detectors = [dt]~detectors;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public void vfsAddPak (const(char)[] fname) {
  vfsAddPak(vfsDiskOpen(fname), fname);
}


public void vfsAddPak(T) (VFile fl, T fname=null) if (is(T : const(char)[])) {
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

  auto opos = fl.tell;

  ptlock.lock();
  scope(exit) ptlock.unlock();

  // try all detectors
  foreach_reverse (VFSDriverDetector dt; detectors) {
    try {
      fl.seek(opos);
      auto drv = dt.tryOpen(fl);
      if (drv !is null) { vfsRegister(drv); return; }
    } catch (Exception e) {
      // chain
      error(e);
    }
  }
  error();
}


// ////////////////////////////////////////////////////////////////////////// //
VFile vfsDiskOpen (const(char)[] fname) {
  static import core.stdc.stdio;
  if (fname.length == 0) throw new VFSException("can't open file ''");
  if (fname.length > 2048) throw new VFSException("can't open file '"~fname.idup~"'");
  char[2049] nbuf;
  nbuf[0..fname.length] = fname[];
  nbuf[fname.length] = '\0';
  auto fl = core.stdc.stdio.fopen(nbuf.ptr, "rb");
  if (fl is null) throw new VFSException("can't open file '"~fname.idup~"'");
  scope(failure) core.stdc.stdio.fclose(fl); // just in case
  try {
    return VFile(fl);
  } catch (Exception e) {
    // chain
    throw new VFSException("can't open file '"~fname.idup~"'", __FILE__, __LINE__, e);
  }
}
