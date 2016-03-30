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
/**
 * wrap any low-level (or high-level) stream into refcounted struct.
 * this struct can be used instead of `std.stdio.File` when you need
 * a concrete type instead of working with generic stream templates.
 * wrapped stream is thread-safe (i.e. reads, writes, etc), but
 * wrapper itself isn't.
 */
module iv.vfs.vfile;
private:
static import core.stdc.stdio;
static import core.sys.posix.stdio;
static import core.sys.posix.unistd;
static import std.stdio;

import iv.vfs : ssize, usize, Seek;
import iv.vfs.error;
import iv.vfs.augs;


// ////////////////////////////////////////////////////////////////////////// //
/// wrapper structure for various streams. kinda like `std.stdio.File`,
/// but with less features. not thread-safe for assigns and such, but
/// thread-safe for i/o. i.e. you'd better not share this struct between
/// threads, but can safely use struct copies in different threads.
public struct VFile {
private:
  /*WrappedStreamRC*/usize wstp; // yep, the whole struct size: one pointer

  @property WrappedStreamRC wst () pure nothrow @trusted @nogc { pragma(inline, true); return *cast(WrappedStreamRC*)&wstp; }

  static bool doDecRef (WrappedStreamRC st) {
    if (st !is null) {
      if (st.decRef) {
        // free `wst` itself
        import core.memory : GC;
        import core.stdc.stdlib : free;
        GC.removeRange(cast(void*)st);
        GC.removeRoot(cast(void*)st);
        free(cast(void*)st);
        return true;
      }
    }
    return false;
  }

  this (void* wptr) { wstp = cast(usize)wptr; }
  //this (usize wptr) { wstp = wptr; }

public:
  this (const VFile fl) {
    wstp = fl.wstp;
    if (wstp) wst.incRef();
  }

  this (std.stdio.File fl) {
    try {
      wstp = WrapStdioFile(fl);
    } catch (Exception e) {
      // chain exception
      throw new VFSException("can't open file", __FILE__, __LINE__, e);
    }
  }

  /// this will throw if `fl` is `null`; `fl` is owned by VFile now
  this (core.stdc.stdio.FILE* fl) {
    if (fl is null) throw new VFSException("can't open file");
    wstp = WrapLibcFile(fl);
  }

  /// wrap file descriptor; `fd` is owned by VFile now; can throw
  this (int fd) {
    if (fd < 0) throw new VFSException("can't open file");
    wstp = WrapFD(fd);
  }

  /// open named file with VFS engine; start with "/" or "./" to use only disk files
  this(T) (T fname) if (is(T : const(char)[])) {
    import iv.vfs.main : vfsOpenFile;
    auto fl = vfsOpenFile(fname);
    wstp = fl.wstp;
    fl.wstp = 0;
  }

  @property const(char)[] name () {
    if (!wstp) return null;
    try {
      return wst.name;
    } catch (Exception e) {
      // chain exception
      throw new VFSException("read error", __FILE__, __LINE__, e);
    }
  }

  @property bool isOpen () {
    if (!wstp) return false;
    try {
      return wst.isOpen;
    } catch (Exception e) {
      // chain exception
      throw new VFSException("read error", __FILE__, __LINE__, e);
    }
  }

  void close () {
    try {
      auto oldo = wst;
      wstp = 0;
      doDecRef(oldo);
    } catch (Exception e) {
      // chain exception
      throw new VFSException("read error", __FILE__, __LINE__, e);
    }
  }

  @property bool eof () { pragma(inline, true); return (!wstp || wst.eof); }

  private import std.traits : isMutable;

  T[] rawRead(T) (T[] buf) if (isMutable!T) {
    if (!isOpen) throw new VFSException("can't read from closed stream");
    if (buf.length > 0) {
      ssize res;
      try {
        synchronized(wst) res = wst.read(buf.ptr, buf.length*T.sizeof);
      } catch (Exception e) {
        // chain exception
        throw new VFSException("read error", __FILE__, __LINE__, e);
      }
      if (res == -1 || res%T.sizeof != 0) throw new VFSException("read error");
      return buf[0..res/T.sizeof];
    } else {
      return buf[0..0];
    }
  }

  void rawWrite(T) (in T[] buf) {
    if (!isOpen) throw new VFSException("can't write to closed stream");
    if (buf.length > 0) {
      ssize res;
      try {
        synchronized(wst) res = wst.write(buf.ptr, buf.length*T.sizeof);
      } catch (Exception e) {
        // chain exception
        throw new VFSException("read error", __FILE__, __LINE__, e);
      }
      if (res == -1 || res%T.sizeof != 0) throw new VFSException("write error");
    }
  }

  void seek (long offset, int origin=Seek.Set) {
    if (!isOpen) throw new VFSException("can't seek in closed stream");
    try {
      synchronized(wst) wst.seek(offset, origin);
    } catch (Exception e) {
      // chain exception
      throw new VFSException("read error", __FILE__, __LINE__, e);
    }
  }

  @property long tell () {
    if (!isOpen) throw new VFSException("can't get position in closed stream");
    try {
      synchronized(wst) return wst.tell;
    } catch (Exception e) {
      // chain exception
      throw new VFSException("read error", __FILE__, __LINE__, e);
    }
  }

  @property long size () {
    if (!isOpen) throw new VFSException("can't get size of closed stream");
    try {
      synchronized(wst) return wst.size;
    } catch (Exception e) {
      // chain exception
      throw new VFSException("read error", __FILE__, __LINE__, e);
    }
  }

  void opAssign (VFile src) {
    if (!wstp && !src.wstp) return;
    try {
      if (wstp) {
        // assigning to opened stream
        if (src.wstp) {
          // both streams are active
          if (wstp == src.wstp) return; // nothing to do
          auto oldo = wst;
          auto newo = src.wst;
          newo.incRef();
          // replace stream object
          wstp = src.wstp;
          // release old stream
          doDecRef(oldo);
        } else {
          // just close this one
          auto oldo = wst;
          wstp = 0;
          doDecRef(oldo);
        }
      } else if (src.wstp) {
        // this stream is closed, but other is active; easy deal
        wstp = src.wstp;
        wst.incRef();
      }
    } catch (Exception e) {
      // chain exception
      throw new VFSException("read error", __FILE__, __LINE__, e);
    }
  }

  usize toHash () const pure nothrow @safe @nogc { pragma(inline, true); return wstp; } // yeah, so simple
  bool opEquals() (auto ref VFile s) const { pragma(inline, true); return (wstp == s.wstp); }
}


// ////////////////////////////////////////////////////////////////////////// //
// base refcounted class for wrapped stream
package class WrappedStreamRC {
protected:
  shared uint rc = 1;

  this () pure nothrow @safe @nogc {}

  // this should never be called
  ~this () nothrow @safe @nogc {
    assert(0); // why we are here?!
  }

  final void incRef () {
    import core.atomic;
    if (atomicOp!"+="(rc, 1) == 0) assert(0); // hey, this is definitely a bug!
  }

  // return true if this class is dead
  final bool decRef () {
    // no need to protect this code with `synchronized`, as only one thread can reach zero rc anyway
    import core.atomic;
    auto xrc = atomicOp!"-="(rc, 1);
    if (xrc == rc.max) assert(0); // hey, this is definitely a bug!
    if (xrc == 0) {
      import core.memory : GC;
      import core.stdc.stdlib : free;
      synchronized(this) close(); // finalize stream
      /*
      if (gcroot) {
        // remove roots
        if (gcrange) {
          GC.removeRange(cast(void*)gcroot);
          GC.removeRoot(cast(void*)gcroot);
        }
        // free allocated memory
        if (libcfree) free(cast(void*)gcroot);
        // just in case
        gcroot = 0;
      }
      */
      return true;
    } else {
      return false;
    }
  }

protected:
  abstract void close ();
  abstract @property const(char)[] name ();
  abstract @property bool isOpen ();
  abstract @property bool eof ();
  ssize read (void* buf, usize count) { return -1; }
  ssize write (in void* buf, usize count) { return -1; }
  void seek (long offset, int origin=Seek.Set) { throw new VFSException("seek is not supported"); }
  @property long tell () { throw new VFSException("tell is not supported"); }
  @property long size () { throw new VFSException("size is not supported"); }
}


// ////////////////////////////////////////////////////////////////////////// //
usize newWS (CT, A...) (A args) if (is(CT : WrappedStreamRC)) {
  import core.exception : onOutOfMemoryErrorNoGC;
  import core.memory : GC;
  import core.stdc.stdlib : malloc;
  import std.conv : emplace;
  enum instSize = __traits(classInstanceSize, CT);
  // let's hope that malloc() aligns returned memory right
  auto mem = malloc(instSize);
  if (mem is null) onOutOfMemoryErrorNoGC(); // oops
  GC.addRoot(mem);
  GC.addRange(mem, instSize);
  emplace!CT(mem[0..instSize], args);
  return cast(usize)mem;
}


// ////////////////////////////////////////////////////////////////////////// //
final class WrappedStreamStdioFile : WrappedStreamRC {
private:
  std.stdio.File fl;

  public this (std.stdio.File afl) { fl = afl; } // fuck! emplace needs it

protected:
  override @property const(char)[] name () { return fl.name; }

  override void close () { if (fl.isOpen) fl.close(); }
  override @property bool isOpen () { return fl.isOpen; }
  override @property bool eof () { return fl.eof; }

  override ssize read (void* buf, usize count) {
    if (count == 0) return 0;
    return fl.rawRead(buf[0..count]).length;
  }

  override ssize write (in void* buf, usize count) {
    if (count == 0) return 0;
    fl.rawWrite(buf[0..count]);
    return count;
  }

  override void seek (long offset, int origin=Seek.Set) { fl.seek(offset, origin); }
  override @property long tell () { return fl.tell; }
  override @property long size () { return fl.size; }
}


usize WrapStdioFile (std.stdio.File fl) {
  return newWS!WrappedStreamStdioFile(fl);
}


// ////////////////////////////////////////////////////////////////////////// //
private import core.stdc.errno;

final class WrappedStreamLibcFile : WrappedStreamRC {
private:
  core.stdc.stdio.FILE* fl;

  public this (core.stdc.stdio.FILE* afl) { fl = afl; } // fuck! emplace needs it

protected:
  override @property const(char)[] name () { return null; }

  override void close () {
    if (fl !is null) {
      import std.exception : ErrnoException;
      auto res = core.stdc.stdio.fclose(fl);
      fl = null;
      if (res != 0) throw new ErrnoException("can't close file", __FILE__, __LINE__);
    }
  }

  override @property bool isOpen () { return (fl !is null); }
  override @property bool eof () { return (fl is null || core.stdc.stdio.feof(fl) != 0); }

  override ssize read (void* buf, usize count) {
    if (fl is null || core.stdc.stdio.ferror(fl)) return -1;
    if (count == 0) return 0;
    auto res = core.stdc.stdio.fread(buf, 1, count, fl);
    if (res == 0) return (core.stdc.stdio.ferror(fl) ? -1 : 0);
    return res;
  }

  override ssize write (in void* buf, usize count) {
    if (fl is null || core.stdc.stdio.ferror(fl)) return -1;
    if (count == 0) return 0;
    auto res = core.stdc.stdio.fwrite(buf, 1, count, fl);
    if (res == 0) return (core.stdc.stdio.ferror(fl) ? -1 : 0);
    return res;
  }

  override void seek (long offset, int origin=Seek.Set) {
    import std.exception : ErrnoException;
    if (fl is null) { errno = EBADF; throw new ErrnoException("can't seek in closed file", __FILE__, __LINE__); }
    if (core.sys.posix.stdio.fseeko(fl, offset, origin) == -1) throw new ErrnoException("seek error", __FILE__, __LINE__);
    core.stdc.stdio.clearerr(fl);
  }

  override @property long tell () {
    import std.exception : ErrnoException;
    if (fl is null) { errno = EBADF; throw new ErrnoException("can't tell in closed file", __FILE__, __LINE__); }
    auto res = core.stdc.stdio.ftell(fl);
    if (res == -1) throw new ErrnoException("tell error", __FILE__, __LINE__);
    return res;
  }

  override @property long size () {
    import std.exception : ErrnoException;
    if (fl is null) { errno = EBADF; throw new ErrnoException("can't seek in closed file", __FILE__, __LINE__); }
    auto opos = core.stdc.stdio.ftell(fl);
    if (opos == -1) throw new ErrnoException("tell error", __FILE__, __LINE__);
    core.stdc.stdio.clearerr(fl);
    if (core.sys.posix.stdio.fseeko(fl, 0, Seek.End) == -1) throw new ErrnoException("seek error", __FILE__, __LINE__);
    auto sz = core.stdc.stdio.ftell(fl);
    if (sz == -1) throw new ErrnoException("tell error", __FILE__, __LINE__);
    if (core.sys.posix.stdio.fseeko(fl, opos, Seek.Set) == -1) throw new ErrnoException("seek error", __FILE__, __LINE__);
    return sz;
  }
}


usize WrapLibcFile (core.stdc.stdio.FILE* fl) {
  return newWS!WrappedStreamLibcFile(fl);
}


// ////////////////////////////////////////////////////////////////////////// //
final class WrappedStreamFD : WrappedStreamRC {
private:
  int fd;
  bool eofhit;

  public this (int afd) { fd = afd; eofhit = (afd < 0); } // fuck! emplace needs it

protected:
  override @property const(char)[] name () { return null; }

  override void close () {
    if (fd >= 0) {
      import std.exception : ErrnoException;
      auto res = core.sys.posix.unistd.close(fd);
      fd = -1;
      eofhit = true;
      if (res < 0) throw new ErrnoException("can't close file", __FILE__, __LINE__);
    }
  }

  override @property bool isOpen () { return (fd >= 0); }
  override @property bool eof () { return eofhit; }

  override ssize read (void* buf, usize count) {
    if (fd < 0) return -1;
    if (count == 0) return 0;
    auto res = core.sys.posix.unistd.read(fd, buf, count);
    if (res != count) eofhit = true;
    return res;
  }

  override ssize write (in void* buf, usize count) {
    if (fd < 0) return -1;
    if (count == 0) return 0;
    auto res = core.sys.posix.unistd.write(fd, buf, count);
    if (res != count) eofhit = true;
    return res;
  }

  override void seek (long offset, int origin=Seek.Set) {
    import std.exception : ErrnoException;
    if (fd < 0) { errno = EBADF; throw new ErrnoException("can't seek in closed file", __FILE__, __LINE__); }
    if (core.sys.posix.unistd.lseek(fd, offset, origin) == -1) throw new ErrnoException("seek error", __FILE__, __LINE__);
    eofhit = false;
  }

  override @property long tell () {
    import std.exception : ErrnoException;
    if (fd < 0) { errno = EBADF; throw new ErrnoException("can't tell in closed file", __FILE__, __LINE__); }
    auto res = core.sys.posix.unistd.lseek(fd, 0, Seek.Cur);
    if (res == -1) throw new ErrnoException("tell error", __FILE__, __LINE__);
    return res;
  }

  override @property long size () {
    import std.exception : ErrnoException;
    if (fd < 0) { errno = EBADF; throw new ErrnoException("can't tell in closed file", __FILE__, __LINE__); }
    auto opos = core.sys.posix.unistd.lseek(fd, 0, Seek.Cur);
    if (opos == -1) throw new ErrnoException("seek error", __FILE__, __LINE__);
    auto sz = core.sys.posix.unistd.lseek(fd, 0, Seek.End);
    if (sz == -1) throw new ErrnoException("seek error", __FILE__, __LINE__);
    if (core.sys.posix.unistd.lseek(fd, opos, Seek.Set) == -1) throw new ErrnoException("seek error", __FILE__, __LINE__);
    return sz;
  }
}


usize WrapFD (int fd) {
  return newWS!WrappedStreamFD(fd);
}


// ////////////////////////////////////////////////////////////////////////// //
final class WrappedStreamAny(ST) : WrappedStreamRC {
private:
  ST st;
  bool eofhit;
  bool closed;

  public this() (auto ref ST ast) { st = ast; } // fuck! emplace needs it

protected:
  override @property const(char)[] name () {
    static if (streamHasName!ST) {
      return (closed ? null : st.name);
    } else {
      return null;
    }
  }

  override void close () {
    if (!closed) {
      closed = true;
      eofhit = true;
      static if (streamHasClose!ST) st.close();
      st = ST.init;
    }
  }

  override @property bool isOpen () {
    static if (streamHasIsOpen!ST) {
      if (closed) return true;
      return st.isOpen;
    } else {
      return !closed;
    }
  }
  override @property bool eof () { return eofhit; }

  override ssize read (void* buf, usize count) {
    if (closed) return -1;
    if (count == 0) return 0;
    static if (isLowLevelStreamR!ST) {
      auto res = st.read(buf, count);
      if (res != count) eofhit = true;
      return res;
    } else static if (isReadableStream!ST) {
      return st.rawRead(buf[0..count]).length;
    } else {
      return -1;
    }
  }

  override ssize write (in void* buf, usize count) {
    if (closed) return -1;
    if (count == 0) return 0;
    static if (isLowLevelStreamW!ST) {
      auto res = st.write(buf, count);
      if (res != count) eofhit = true;
      return res;
    } else static if (isWriteableStream!ST) {
      st.rawWrite(buf[0..count]);
      return count;
    } else {
      return -1;
    }
  }

  override void seek (long offset, int origin=Seek.Set) {
    if (closed) throw new VFSException("can't seek in closed stream");
    static if (streamHasSeek!ST) {
      st.seek(offset, origin);
      eofhit = false;
    } else {
      throw new VFSException("seek error");
    }
  }

  override @property long tell () {
    if (closed) throw new VFSException("can't seek in closed stream");
    static if (streamHasTell!ST) {
      return st.tell;
    } else {
      throw new VFSException("tell error");
    }
  }

  override @property long size () {
    if (closed) throw new VFSException("can't seek in closed stream");
    static if (streamHasSize!ST) {
      return st.size;
    } else {
      throw new VFSException("can't get stream size");
    }
  }
}


/// wrap any valid stream into VFile
public VFile wrapStream (std.stdio.File st) { return VFile(st); }

/// wrap any valid stream into VFile
public VFile wrapStream (VFile st) { return VFile(st); }

/// wrap any valid stream into VFile
public VFile wrapStream (core.stdc.stdio.FILE* st) { return VFile(st); }

/// wrap any valid stream into VFile
public VFile wrapStream (int st) { return VFile(st); }

/// ditto
public VFile wrapStream(ST) (auto ref ST st) if (isReadableStream!ST || isWriteableStream!ST) { return VFile(cast(void*)newWS!(WrappedStreamAny!ST)(st)); }
