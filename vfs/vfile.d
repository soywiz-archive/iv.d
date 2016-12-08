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

import iv.vfs.types : ssize, usize, Seek;
import iv.vfs.config;
import iv.vfs.error;
import iv.vfs.augs;
import iv.vfs.streams.mem;

version(LDC) {}
else { version = vfs_stdio_wrapper; }


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
      debug(vfs_rc) { import core.stdc.stdio : printf; printf("DO DECREF FOR 0x%08x\n", cast(void*)st); }
      if (st.decRef) {
        // free `wst` itself
        import core.memory : GC;
        import core.stdc.stdlib : free;
        debug(vfs_vfile_gc) { import core.stdc.stdio : printf; printf("REMOVING WRAPPER 0x%08x\n", st); }
        if (st.gcUnregister !is null) {
          debug(vfs_vfile_gc) { import core.stdc.stdio : printf; printf("CALLING GC CLEANUP DELEGATE FOR WRAPPER 0x%08x\n", st); }
          st.gcUnregister(cast(void*)st);
        }
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

  version(vfs_stdio_wrapper)
  this (std.stdio.File fl, string fname=null) {
    try {
      wstp = WrapStdioFile(fl, fname);
    } catch (Exception e) {
      // chain exception
      throw new VFSException("can't open file", __FILE__, __LINE__, e);
    }
  }

  /// this will throw if `fl` is `null`; `fl` is (not) owned by VFile now
  this (core.stdc.stdio.FILE* fl, bool own=true) {
    if (fl is null) throw new VFSException("can't open file");
    if (own) wstp = WrapLibcFile!true(fl, null); else wstp = WrapLibcFile!false(fl, null);
  }

  /// this will throw if `fl` is `null`; `fl` is (not) owned by VFile now
  this (core.stdc.stdio.FILE* fl, string fname, bool own=true) {
    if (fl is null) throw new VFSException("can't open file");
    if (own) wstp = WrapLibcFile!true(fl, fname); else wstp = WrapLibcFile!false(fl, fname);
  }

  /// wrap file descriptor; `fd` is owned by VFile now; can throw
  static if (VFS_NORMAL_OS) this (int fd, bool own=true) {
    if (fd < 0) throw new VFSException("can't open file");
    if (own) wstp = WrapFD!true(fd, null); else wstp = WrapFD!true(fd, null);
  }

  /// wrap file descriptor; `fd` is owned by VFile now; can throw
  static if (VFS_NORMAL_OS) this (int fd, string fname, bool own=true) {
    if (fd < 0) throw new VFSException("can't open file");
    if (own) wstp = WrapFD!true(fd, fname); else wstp = WrapFD!true(fd, fname);
  }

  /// open named file with VFS engine; start with "/" or "./" to use only disk files
  this(T) (T fname, const(char)[] mode=null) if (is(T : const(char)[])) {
    import iv.vfs.main : vfsOpenFile;
    debug(vfs_rc) { import core.stdc.stdio : printf; printf("CTOR:STR(%.*s)\n", cast(uint)fname.length, fname.ptr); }
    auto fl = vfsOpenFile(fname, mode);
    debug(vfs_rc) { import core.stdc.stdio : printf; printf("CTOR(0x%08x)\n", cast(void*)fl.wstp); }
    wstp = fl.wstp;
    fl.wstp = 0;
    //this = fl;
  }

  this (this) {
    debug(vfs_rc) { import core.stdc.stdio : printf; printf("POSTBLIT(0x%08x)\n", cast(void*)wstp); }
    debug(vfs_rc_trace) {
      try { throw new Exception("stack trace"); } catch (Exception e) { import std.stdio; writeln("*** ", e.toString); }
    }
    if (wst !is null) wst.incRef();
  }

  ~this () {
    debug(vfs_rc) { import core.stdc.stdio : printf; printf("DTOR(0x%08x)\n", cast(void*)wstp); }
    debug(vfs_rc_trace) {
      try { throw new Exception("stack trace"); } catch (Exception e) { import std.stdio; writeln("*** ", e.toString); }
    }
    doDecRef(wst);
  }

  @property bool opCast(T) () if (is(T == bool)) { pragma(inline, true); return this.isOpen; }

  @property const(char)[] name () {
    if (!wstp) return null;
    try {
      synchronized(wst) return wst.name;
    } catch (Exception e) {
      // chain exception
      throw new VFSException("read error", __FILE__, __LINE__, e);
    }
  }

  @property bool isOpen () {
    if (!wstp) return false;
    try {
      synchronized(wst) return wst.isOpen;
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

  long seek (long offset, int origin=Seek.Set) {
    if (!isOpen) throw new VFSException("can't seek in closed stream");
    long p;
    try {
      synchronized(wst) p = wst.lseek(offset, origin);
    } catch (Exception e) {
      // chain exception
      throw new VFSException("seek error", __FILE__, __LINE__, e);
    }
    if (p == -1) throw new VFSException("seek error");
    return p;
  }

  @property long tell () {
    if (!isOpen) throw new VFSException("can't get position in closed stream");
    long p;
    try {
      synchronized(wst) p = wst.lseek(0, Seek.Cur);
    } catch (Exception e) {
      // chain exception
      throw new VFSException("tell error", __FILE__, __LINE__, e);
    }
    if (p == -1) throw new VFSException("tell error");
    return p;
  }

  @property long size () {
    if (!isOpen) throw new VFSException("can't get size of closed stream");
    bool noChain = false;
    long p;
    try {
      synchronized(wst) {
        auto opos = wst.lseek(0, Seek.Cur);
        if (opos == -1) { noChain = true; throw new VFSException("size error"); }
        p = wst.lseek(0, Seek.End);
        if (p == -1) { noChain = true; throw new VFSException("size error"); }
        if (wst.lseek(opos, Seek.Set) == -1) { noChain = true; throw new VFSException("size error"); }
      }
    } catch (Exception e) {
      // chain exception
      if (noChain) throw e;
      throw new VFSException("size error", __FILE__, __LINE__, e);
    }
    return p;
  }

  void opAssign (VFile src) {
    if (!wstp && !src.wstp) return;
    try {
      debug(vfs_rc) { import core.stdc.stdio : printf; printf("***OPASSIGN(0x%08x -> 0x%08x)\n", cast(void*)src.wstp, cast(void*)wstp); }
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
  bool eofhit;
  //string fname;
  char[512] fnamebuf=0;
  size_t fnameptr;
  size_t fnamelen;

  this () pure nothrow @safe @nogc {}

  final void setFileName (const(char)[] aname) {
    if (aname.length) {
      if (aname.length <= fnamebuf.length) {
        if (fnameptr) { import core.stdc.stdlib : free; free(cast(void*)fnameptr); fnameptr = 0; }
        fnamebuf[0..aname.length] = aname;
        fnamelen = aname.length;
      } else {
        import core.stdc.stdlib : realloc;
        auto nb = cast(char*)realloc(cast(void*)fnameptr, aname.length);
        if (nb !is null) {
          nb[0..aname.length] = aname[];
          fnameptr = cast(size_t)nb;
          fnamelen = aname.length;
        }
      }
    } else {
      if (fnameptr) { import core.stdc.stdlib : free; free(cast(void*)fnameptr); fnameptr = 0; }
      fnamelen = 0;
    }
  }

  // this shouldn't be called, ever
  ~this () nothrow @trusted {
    assert(0); // why we are here?!
    //if (gcUnregister !is null) gcUnregister(cast(void*)this);
  }

  final void incRef () {
    import core.atomic;
    if (atomicOp!"+="(rc, 1) == 0) assert(0); // hey, this is definitely a bug!
    debug(vfs_rc) { import core.stdc.stdio : printf; printf("INCREF(0x%08x): %u (was %u)...\n", cast(void*)this, rc, rc-1); }
  }

  // return true if this class is dead
  final bool decRef () {
    // no need to protect this code with `synchronized`, as only one thread can reach zero rc anyway
    import core.atomic;
    debug(vfs_rc) { import core.stdc.stdio : printf; printf("DECREF(0x%08x): %u (will be %u)...\n", cast(void*)this, rc, rc-1); }
    auto xrc = atomicOp!"-="(rc, 1);
    debug(vfs_rc) { import core.stdc.stdio : printf; printf("  DECREF(0x%08x): %u %u...\n", cast(void*)this, rc, xrc); }
    if (xrc == rc.max) assert(0); // hey, this is definitely a bug!
    if (xrc == 0) {
      import core.memory : GC;
      import core.stdc.stdlib : free;
      synchronized(this) close(); // finalize stream; should be synchronized right here
      return true;
    } else {
      return false;
    }
  }

protected:
  void function (void* self) nothrow gcUnregister;

protected:
  final bool hasName () const pure nothrow @safe @nogc { pragma(inline, true); return (fnamelen != 0); }
  @property const(char)[] name () { return (fnamelen ? (fnameptr ? (cast(const(char)*)fnameptr)[0..fnamelen] : fnamebuf.ptr[0..fnamelen]) : ""); }
  @property bool eof () { return eofhit; }
  abstract @property bool isOpen ();
  abstract void close ();
  ssize read (void* buf, usize count) { return -1; }
  ssize write (in void* buf, usize count) { return -1; }
  long lseek (long offset, int origin) { return -1; }
}


// ////////////////////////////////////////////////////////////////////////// //
usize newWS (CT, A...) (A args) if (is(CT : WrappedStreamRC)) {
  import core.exception : onOutOfMemoryErrorNoGC;
  import core.memory : GC;
  import core.stdc.stdlib : malloc;
  import core.stdc.string : memset;
  import std.conv : emplace;
  enum instSize = __traits(classInstanceSize, CT);
  // let's hope that malloc() aligns returned memory right
  auto mem = malloc(instSize);
  if (mem is null) onOutOfMemoryErrorNoGC(); // oops
  memset(mem, 0, instSize);
  //GC.addRoot(mem);
  GC.addRange(mem, instSize);
  emplace!CT(mem[0..instSize], args);
  bool createUnregister = false;
  {
    debug(vfs_vfile_gc) import core.stdc.stdio : printf;
    auto pbm = __traits(getPointerBitmap, CT);
    debug(vfs_vfile_gc) printf("[%.*s]: size=%u (%u) (%u)\n", cast(uint)CT.stringof.length, CT.stringof.ptr, cast(uint)pbm[0], cast(uint)instSize, cast(uint)(pbm[0]/size_t.sizeof));
    immutable(ubyte)* p = cast(immutable(ubyte)*)(pbm.ptr+1);
    size_t bitnum = 0;
    immutable end = pbm[0]/size_t.sizeof;
    while (bitnum < end) {
      if (p[bitnum/8]&(1U<<(bitnum%8))) {
        size_t len = 1;
        while (bitnum+len < end && (p[(bitnum+len)/8]&(1U<<((bitnum+len)%8))) != 0) ++len;
        debug(vfs_vfile_gc) printf("  #%u (%u)\n", cast(uint)(bitnum*size_t.sizeof), cast(uint)len);
        GC.addRange((cast(size_t*)mem)+bitnum, size_t.sizeof*len);
        createUnregister = true;
        bitnum += len;
      } else {
        ++bitnum;
      }
    }
  }
  if (createUnregister) {
    debug(vfs_vfile_gc) { import core.stdc.stdio : printf; printf("REGISTERING CG CLEANUP DELEGATE FOR WRAPPER 0x%08x\n", cast(uint)mem); }
    (*cast(CT*)&mem).gcUnregister = function (void* self) {
      debug(vfs_vfile_gc) import core.stdc.stdio : printf;
      debug(vfs_vfile_gc) { import core.stdc.stdio : printf; printf("DESTROYING WRAPPER 0x%08x\n", cast(uint)self); }
      auto pbm = __traits(getPointerBitmap, CT);
      debug(vfs_vfile_gc) printf("[%.*s]: size=%u (%u) (%u)\n", cast(uint)CT.stringof.length, CT.stringof.ptr, cast(uint)pbm[0], cast(uint)instSize, cast(uint)(pbm[0]/size_t.sizeof));
      immutable(ubyte)* p = cast(immutable(ubyte)*)(pbm.ptr+1);
      size_t bitnum = 0;
      immutable end = pbm[0]/size_t.sizeof;
      while (bitnum < end) {
        if (p[bitnum/8]&(1U<<(bitnum%8))) {
          size_t len = 1;
          while (bitnum+len < end && (p[(bitnum+len)/8]&(1U<<((bitnum+len)%8))) != 0) ++len;
          debug(vfs_vfile_gc) printf("  #%u (%u)\n", cast(uint)(bitnum*size_t.sizeof), cast(uint)len);
          GC.removeRange((cast(size_t*)self)+bitnum);
          bitnum += len;
        } else {
          ++bitnum;
        }
      }
    };
  }
  debug(vfs_vfile_gc) { import core.stdc.stdio : printf; printf("CREATED WRAPPER 0x%08x\n", mem); }
  return cast(usize)mem;
}


// ////////////////////////////////////////////////////////////////////////// //
version(vfs_stdio_wrapper)
final class WrappedStreamStdioFile : WrappedStreamRC {
private:
  std.stdio.File fl;

  public this (std.stdio.File afl, const(char)[] afname) { fl = afl; setFileName(afname); } // fuck! emplace needs it

protected:
  override @property const(char)[] name () { return (hasName ? super.name : fl.name); }
  override @property bool isOpen () { return fl.isOpen; }
  override @property bool eof () { return fl.eof; }

  override void close () { if (fl.isOpen) fl.close(); }

  override ssize read (void* buf, usize count) {
    if (count == 0) return 0;
    return fl.rawRead(buf[0..count]).length;
  }

  override ssize write (in void* buf, usize count) {
    if (count == 0) return 0;
    fl.rawWrite(buf[0..count]);
    return count;
  }

  override long lseek (long offset, int origin) { fl.seek(offset, origin); return fl.tell; }
}


version(vfs_stdio_wrapper)
usize WrapStdioFile (std.stdio.File fl, string fname=null) {
  return newWS!WrappedStreamStdioFile(fl, fname);
}


// ////////////////////////////////////////////////////////////////////////// //
private import core.stdc.errno;

final class WrappedStreamLibcFile(bool ownfl=true) : WrappedStreamRC {
private:
  //core.stdc.stdio.FILE* fl;
  size_t flp; // hide from GC
  final @property core.stdc.stdio.FILE* fl () const pure nothrow @trusted @nogc { pragma(inline, true); return cast(core.stdc.stdio.FILE*)flp; }
  final @property void fl (core.stdc.stdio.FILE* afl) pure nothrow @trusted @nogc { pragma(inline, true); flp = cast(size_t)afl; }

  public this (core.stdc.stdio.FILE* afl, const(char)[] afname) { fl = afl; setFileName(afname); } // fuck! emplace needs it

protected:
  override @property bool isOpen () { return (fl !is null); }
  override @property bool eof () { return (fl is null || core.stdc.stdio.feof(fl) != 0); }

  override void close () {
    if (fl !is null) {
      static if (ownfl) {
        import std.exception : ErrnoException;
        auto res = core.stdc.stdio.fclose(fl);
        fl = null;
        if (res != 0) throw new ErrnoException("can't close file", __FILE__, __LINE__);
      } else {
        fl = null;
      }
    }
  }

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

  override long lseek (long offset, int origin) {
    if (fl is null) return -1;
    static if (VFS_NORMAL_OS) {
      auto res = core.sys.posix.stdio.fseeko(fl, offset, origin);
    } else {
      // windoze sux
      if (offset < int.min || offset > int.max) return -1;
      auto res = core.stdc.stdio.fseek(fl, cast(int)offset, origin);
    }
    if (res != -1) core.stdc.stdio.clearerr(fl);
    static if (VFS_NORMAL_OS) {
      return core.sys.posix.stdio.ftello(fl);
    } else {
      return core.stdc.stdio.ftell(fl);
    }
  }
}


usize WrapLibcFile(bool ownfl=true) (core.stdc.stdio.FILE* fl, string fname=null) {
  return newWS!(WrappedStreamLibcFile!ownfl)(fl, fname);
}


// ////////////////////////////////////////////////////////////////////////// //
static if (VFS_NORMAL_OS) final class WrappedStreamFD(bool own) : WrappedStreamRC {
private:
  int fd;

  public this (int afd, const(char)[] afname) { fd = afd; eofhit = (afd < 0); setFileName(afname); } // fuck! emplace needs it

protected:
  override @property bool isOpen () { return (fd >= 0); }

  override void close () {
    if (fd >= 0) {
      import std.exception : ErrnoException;
      static if (own) {
        debug(vfs_rc) { import core.stdc.stdio : printf; printf("******** CLOSING FD %u\n", cast(uint)fd); }
      } else {
        debug(vfs_rc) { import core.stdc.stdio : printf; printf("******** RELEASING FD %u\n", cast(uint)fd); }
      }
      static if (own) auto res = core.sys.posix.unistd.close(fd);
      fd = -1;
      eofhit = true;
      static if (own) if (res < 0) throw new ErrnoException("can't close file", __FILE__, __LINE__);
    } else {
      fd = -1;
      eofhit = true;
    }
  }

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

  override long lseek (long offset, int origin) {
    if (fd < 0) return -1;
    auto res = core.sys.posix.unistd.lseek(fd, offset, origin);
    if (res != -1) eofhit = false;
    return res;
  }
}


static if (VFS_NORMAL_OS) usize WrapFD(bool own) (int fd, string fname=null) {
  return newWS!(WrappedStreamFD!own)(fd, fname);
}


// ////////////////////////////////////////////////////////////////////////// //
final class WrappedStreamAny(ST) : WrappedStreamRC {
private:
  ST st;
  bool closed;

   // fuck! emplace needs it
  public this() (auto ref ST ast, const(char)[] afname) {
    st = ast;
    setFileName(afname);
    static if (streamHasIsOpen!ST) {
      closed = !st.isOpen;
    } else {
      closed = false;
    }
  }

protected:
  override @property const(char)[] name () {
    static if (streamHasName!ST) {
      return (closed ? null : (hasName ? super.name : st.name));
    } else {
      return super.name;
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

  override @property bool eof () {
    if (closed) return true;
    static if (streamHasEof!ST) {
      return st.eof;
    } else {
      return eofhit;
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

  override long lseek (long offset, int origin) {
    if (origin != Seek.Set && origin != Seek.Cur && origin != Seek.End) return -1;
    static if (isLowLevelStreamS!ST) {
      // has low-level seek
      if (closed) return -1;
      auto res = st.lseek(offset, origin);
      if (res != -1) eofhit = false;
      return res;
    } else static if (streamHasSeek!ST) {
      // has high-level seek
      if (closed) return -1;
      st.seek(offset, origin);
      eofhit = false;
      return st.tell;
    } else {
      // no seek at all
      return -1;
    }
  }
}


/// wrap `std.stdio.File` into `VFile`
version(vfs_stdio_wrapper)
public VFile wrapStream (std.stdio.File st, string fname=null) { return VFile(st, fname); }

/// wrap another `VFile` into `VFile`
public VFile wrapStream (VFile st) { return VFile(st); }

/// wrap libc `FILE*` into `VFile`
public VFile wrapStream (core.stdc.stdio.FILE* st, string fname=null) { return VFile(st, fname); }

static if (VFS_NORMAL_OS) {
/// wrap file descriptor into `VFile`
public VFile wrapStream (int st, string fname=null) { return VFile(st, fname); }
}

/** wrap any valid i/o stream into `VFile`.
 * "valid" stream should emplement one of two interfaces described below.
 * only one thread can call stream operations at a time, it's guaranteed by `VFile`.
 * note that any function is free to throw, `VFile` will take care of that.
 *
 * low-level interface:
 *
 * [mandatory] `ssize read (void* buf, usize count);`
 *
 *   read bytes; should read up to `count` bytes and return number of bytes read.
 *   should return -1 on error. can't be called with `count == 0`.
 *
 * [mandatory] `ssize write (in void* buf, usize count);`
 *
 *   write bytes; should write exactly `count` bytes and return number of bytes written.
 *   should return -1 on error. can't be called with `count == 0`. note that if you
 *   will return something that is not equal to `count` (i.e. will write less bytes than
 *   requested), `VFile` will throw.
 *
 * [mandatory] `long lseek (long offset, int origin);`
 *
 *   seek into stream. `origin` is one of `Seek.Set`, `Seek.Cur`, or `Seek.End` (can't be
 *   called with another values). should return resulting offset from stream start or -1
 *   on error. note that this method will be used to implement `tell()` and `size()`
 *   VFile APIs, so make it as fast as you can.
 *
 * or high-level interface:
 *
 * [mandatory] `void[] rawRead (void[] buf);`
 *
 *   read bytes; should read up to `buf.length` bytes and return slice with read bytes.
 *   should throw on error. can't be called with empty buf.
 *
 * [mandatory] `void rawWrite (in void[] buf);`
 *
 *   write bytes; should write exactly `buf.length` bytes.
 *   should throw on error (note that if it wrote less bytes than requested, it is an
 *   error too).
 *
 * [mandatory] `void seek (long offset, int origin);`
 *
 *   seek into stream. `origin` is one of `Seek.Set`, `Seek.Cur`, or `Seek.End`.
 *   should throw on error (including invalid `origin`).
 *
 * [mandatory] `@property long tell ();`
 *
 *   should return current position in stream. should throw on error.
 *
 * [mandatory] `@property long size ();`
 *
 *   should return stream size. should throw on error.
 *
 * common interface, optional:
 *
 * [optional] `@property const(char)[] name ();`
 *
 *   should return stream name, or throw on error. can return empty name.
 *
 * [optional] `@property bool isOpen ();`
 *
 *   should return `true` if the stream is opened, or throw on error.
 *
 * [optional] `@property bool eof ();`
 *
 *   should return `true` if end of stream is reached, or throw on error.
 *   note that EOF flag may be set in i/o methods, so you can be at EOF,
 *   but this method can still return `false`. i.e. it is unreliable.
 *
 * [optional] `void close ();`
 *
 *   should close stream, or throw on error. VFile won't call that on
 *   streams that returns `false` from `isOpen()`, but you'd better
 *   handle this situation yourself.
 */
public VFile wrapStream(ST) (auto ref ST st, string fname=null) if (isReadableStream!ST || isWriteableStream!ST) { return VFile(cast(void*)newWS!(WrappedStreamAny!ST)(st, fname)); }


// ////////////////////////////////////////////////////////////////////////// //
private struct PartialLowLevelRO {
  VFile zfl; // original file
  long stpos; // starting position
  long size; // unpacked size
  long pos; // current file position
  bool eofhit;
  //string fname;
  char[512] fnamebuf=0;
  size_t fnameptr;
  size_t fnamelen;

  this (VFile fl, long astpos, long asize, const(char)[] aname) {
    stpos = astpos;
    size = asize;
    zfl = fl;
    if (aname.length) {
      if (aname.length <= fnamebuf.length) {
        fnamebuf[0..aname.length] = aname;
        fnamelen = aname.length;
      } else {
        import core.stdc.stdlib : malloc;
        auto nb = cast(char*)malloc(aname.length+1);
        if (nb !is null) {
          nb[0..aname.length] = 0;
          nb[0..aname.length] = aname[];
          fnameptr = cast(size_t)nb;
          fnamelen = aname.length;
        }
      }
    }
  }

  @property const(char)[] name () { pragma(inline, true); return (fnamelen ? (fnameptr ? (cast(const(char)*)fnameptr)[0..fnamelen] : fnamebuf[0..fnamelen]) : zfl.name); }
  @property bool isOpen () { pragma(inline, true); return zfl.isOpen; }
  @property bool eof () { pragma(inline, true); return eofhit; }

  void close () {
    eofhit = true;
    if (fnameptr) { import core.stdc.stdlib : free; free(cast(void*)fnameptr); fnameptr = 0; }
    if (zfl.isOpen) zfl.close();
  }

  ssize read (void* buf, usize count) {
    if (buf is null) return -1;
    if (count == 0 || size == 0) return 0;
    if (!isOpen) return -1; // read error
    if (pos >= size) { eofhit = true; return 0; } // EOF
    if (size-pos < count) { eofhit = true; count = cast(usize)(size-pos); }
    zfl.seek(stpos+pos);
    auto rd = zfl.rawRead(buf[0..count]);
    pos += rd.length;
    return rd.length;
  }

  ssize write (in void* buf, usize count) { pragma(inline, true); return -1; }

  long lseek (long ofs, int origin) {
    if (!isOpen) return -1;
    //TODO: overflow checks
    switch (origin) {
      case Seek.Set: break;
      case Seek.Cur: ofs += pos; break;
      case Seek.End:
        if (ofs > 0) ofs = 0;
        ofs += size;
        break;
      default:
        return -1;
    }
    if (ofs < 0) return -1;
    eofhit = false;
    if (ofs > size) ofs = size;
    pos = ofs;
    return pos;
  }
}


/// wrap VFile into read-only stream, with given offset and length.
/// if `len` == -1, wrap from starting position to file end.
public VFile wrapStreamRO (VFile st, long stpos=0, long len=-1, string fname=null) {
  if (stpos < 0) throw new VFSException("invalid starting position");
  if (len == -1) len = st.size-stpos;
  if (len < 0) throw new VFSException("invalid length");
  return wrapStream(PartialLowLevelRO(st, stpos, len, fname), fname);
}


// ////////////////////////////////////////////////////////////////////////// //
public enum VFSZLibMode {
  Raw,
  ZLib,
  Zip, // special mode for zip archives
}


// ////////////////////////////////////////////////////////////////////////// //
struct ZLibLowLevelRO {
  private import etc.c.zlib;

  enum ibsize = 32768;


  VFile zfl; // archive file
  VFSZLibMode mode;
  long stpos; // starting position
  long size; // unpacked size
  long pksize; // packed size
  long pos; // current file position
  long prpos; // previous file position
  long pkpos; // current position in DAT
  ubyte[] pkb; // packed data
  z_stream zs;
  bool eoz;
  bool eofhit;
  string fname;

  this (VFile fl, VFSZLibMode amode, long aupsize, long astpos, long asize, string aname) {
    if (amode == VFSZLibMode.Raw && aupsize < 0) aupsize = asize;
    zfl = fl;
    stpos = astpos;
    size = aupsize;
    pksize = asize;
    mode = amode;
    fname = aname;
  }

  @property const(char)[] name () { pragma(inline, true); return (fname !is null ? fname : zfl.name); }
  @property bool isOpen () { pragma(inline, true); return zfl.isOpen; }
  @property bool eof () { pragma(inline, true); return eofhit; }

  void close () {
    import core.stdc.stdlib : free;
    eofhit = true;
    if (pkb.length) {
      inflateEnd(&zs);
      free(pkb.ptr);
      pkb = null;
    }
    eoz = true;
    if (zfl.isOpen) zfl.close();
  }

  private bool initZStream (bool reinit=false) {
    import core.stdc.stdlib : malloc, free;
    if (mode == VFSZLibMode.Raw || (!reinit && pkb.ptr !is null)) return true;
    // allocate buffer for packed data
    if (pkb.ptr is null) {
      auto pb = cast(ubyte*)malloc(ibsize);
      if (pb is null) return false;
      pkb = pb[0..ibsize];
    }
    zs.avail_in = 0;
    zs.avail_out = 0;
    // initialize unpacker
    // -15 is a magic value used to decompress zip files:
    // it has the effect of not requiring the 2 byte header and 4 byte trailer
    if (inflateInit2(&zs, (mode == VFSZLibMode.Zip ? -15 : 15)) != Z_OK) {
      free(pkb.ptr);
      pkb = null;
      return false;
    }
    eoz = false;
    // we are ready
    return true;
  }

  private bool readPackedChunk () {
    if (zs.avail_in > 0) return true;
    if (pkpos >= pksize) return false;
    zs.next_in = cast(typeof(zs.next_in))pkb.ptr;
    zs.avail_in = cast(uint)(pksize-pkpos > ibsize ? ibsize : pksize-pkpos);
    zfl.seek(stpos+pkpos);
    auto rd = zfl.rawRead(pkb[0..zs.avail_in]);
    if (rd.length == 0) return false;
    zs.avail_in = cast(int)rd.length;
    pkpos += zs.avail_in;
    return true;
  }

  private bool unpackNextChunk () {
    while (zs.avail_out > 0) {
      if (eoz) return (size < 0); // `false` for known size, `true` for unknown size
      if (!readPackedChunk()) return false;
      auto err = inflate(&zs, Z_SYNC_FLUSH);
      //if (err == Z_BUF_ERROR) { import iv.writer; writeln("*** OUT OF BUFFER!"); }
      if (err != Z_STREAM_END && err != Z_OK) return false;
      if (err == Z_STREAM_END) eoz = true;
    }
    return true;
  }

  bool findUnpackedSize () {
    ubyte[1024] tbuf = void;
    //size = pos; // current size
    for (;;) {
      uint rd = cast(uint)tbuf.length;
      zs.next_out = cast(typeof(zs.next_out))tbuf.ptr;
      zs.avail_out = rd;
      if (!unpackNextChunk()) return false;
      rd -= zs.avail_out;
      if (pos+rd < 0) return false; // file too big
      prpos = (pos += rd);
      if (zs.avail_out != 0) break;
    }
    size = pos;
    return true;
  }

  ssize read (void* buf, usize count) {
    if (buf is null) return -1;
    if (count == 0 || size == 0) return 0;
    if (!isOpen) return -1; // read error
    if (size >= 0 && pos >= size) { eofhit = true; return 0; } // EOF
    if (mode == VFSZLibMode.Raw) {
      if (size-pos < count) { eofhit = true; count = cast(usize)(size-pos); }
      zfl.seek(stpos+pos);
      auto rd = zfl.rawRead(buf[0..count]);
      pos += rd.length;
      return rd.length;
    } else {
      if (pkb.ptr is null && !initZStream()) return -1;
      // do we want to seek backward?
      if (prpos > pos) {
        // yes, rewind
        inflateEnd(&zs);
        zs = zs.init;
        pkpos = 0;
        if (!initZStream(true)) return -1;
        prpos = 0;
      }
      // do we need to seek forward?
      if (prpos < pos) {
        // yes, skip data
        ubyte[1024] tbuf = void;
        auto skp = pos-prpos;
        while (skp > 0) {
          uint rd = cast(uint)(skp > tbuf.length ? tbuf.length : skp);
          zs.next_out = cast(typeof(zs.next_out))tbuf.ptr;
          zs.avail_out = rd;
          if (!unpackNextChunk()) return -1;
          skp -= rd;
        }
        prpos = pos;
      }
      // unpack data
      if (size >= 0 && size-pos < count) { eofhit = true; count = cast(usize)(size-pos); }
      zs.next_out = cast(typeof(zs.next_out))buf;
      zs.avail_out = cast(uint)count;
      if (!unpackNextChunk()) return -1;
      if (size < 0 && zs.avail_out > 0) {
        eofhit = true;
        count -= zs.avail_out;
        size = pos+count;
      }
      prpos = (pos += count);
      return count;
    }
  }

  ssize write (in void* buf, usize count) { pragma(inline, true); return -1; }

  long lseek (long ofs, int origin) {
    if (!isOpen) return -1;
    //TODO: overflow checks
    switch (origin) {
      case Seek.Set: break;
      case Seek.Cur: ofs += pos; break;
      case Seek.End:
        if (ofs > 0) ofs = 0;
        if (size < 0) {
          if (pkb.ptr is null && !initZStream()) return -1;
          if (!findUnpackedSize) return -1;
        }
        ofs += size;
        break;
      default:
        return -1;
    }
    if (ofs < 0) return -1;
    if (size >= 0 && ofs > size) ofs = size;
    pos = ofs;
    eofhit = false;
    return pos;
  }
}


/// wrap VFile into read-only zlib-packed stream, with given offset and length.
/// if `len` == -1, wrap from starting position to file end.
/// `upsize`: size of unpacked file (-1: size unknown)
public VFile wrapZLibStreamRO (VFile st, VFSZLibMode mode, long upsize, long stpos=0, long len=-1, string fname=null) {
  if (stpos < 0) throw new VFSException("invalid starting position");
  if (upsize < 0 && upsize != -1) throw new VFSException("invalid unpacked size");
  if (len == -1) len = st.size-stpos;
  if (len < 0) throw new VFSException("invalid length");
  return wrapStream(ZLibLowLevelRO(st, mode, upsize, stpos, len, fname), fname);
}

/// the same as previous function, but using VFSZLibMode.ZLib, as most people is using it
public VFile wrapZLibStreamRO (VFile st, long upsize, long stpos=0, long len=-1, string fname=null) {
  return wrapZLibStreamRO(st, VFSZLibMode.ZLib, upsize, stpos, len, fname);
}


// ////////////////////////////////////////////////////////////////////////// //
struct ZLibLowLevelWO {
  private import etc.c.zlib;

  enum obsize = 32768;

  VFile zfl; // destination file
  VFSZLibMode mode;
  long stpos; // starting position
  long pos; // current file position (from stpos)
  long prpos; // previous file position (from stpos)
  ubyte[] pkb; // packed data
  z_stream zs;
  bool eofhit;
  int complevel;
  string fname;

  this (VFile fl, VFSZLibMode amode, int acomplevel=-1, string aname=null) {
    zfl = fl;
    stpos = fl.tell;
    mode = amode;
    if (acomplevel < 0) acomplevel = 6;
    if (acomplevel > 9) acomplevel = 9;
    complevel = 9;
    fname = aname;
  }

  @property const(char)[] name () { pragma(inline, true); return (fname !is null ? fname : zfl.name); }
  @property bool isOpen () { pragma(inline, true); return !eofhit && zfl.isOpen; }
  @property bool eof () { pragma(inline, true); return isOpen; }

  void close () {
    scope(exit) {
      import core.stdc.stdlib : free;
      eofhit = true;
      if (pkb !is null) free(pkb.ptr);
      pkb = null;
    }
    //{ import core.stdc.stdio : printf; printf("CLOSING...\n"); }
    if (!eofhit) {
      scope(exit) zfl.close();
      if (zfl.isOpen && pkb !is null) {
        int err;
        // do leftovers
        //{ import core.stdc.stdio : printf; printf("writing %u bytes; avail_out: %u bytes\n", cast(uint)zs.avail_in, cast(uint)zs.avail_out); }
        for (;;) {
          zs.avail_in = 0;
          err = deflate(&zs, Z_FINISH);
          if (err != Z_OK && err != Z_STREAM_END && err != Z_BUF_ERROR) {
            //{ import core.stdc.stdio; printf("cerr: %d\n", err); }
            throw new VFSException("zlib compression error");
          }
          if (zs.avail_out < obsize) {
            //{ import core.stdc.stdio : printf; printf("flushing %u bytes (avail_out: %u bytes)\n", cast(uint)(obsize-zs.avail_out), cast(uint)zs.avail_out); }
            if (prpos != pos) throw new VFSException("zlib compression seek error");
            zfl.seek(stpos+pos);
            zfl.rawWriteExact(pkb[0..obsize-zs.avail_out]);
            pos += obsize-zs.avail_out;
            prpos = pos;
            zs.next_out = pkb.ptr;
            zs.avail_out = obsize;
          }
          if (err != Z_OK && err != Z_BUF_ERROR) break;
        }
        // succesfully flushed?
        if (err != Z_STREAM_END) throw new VFSException("zlib compression error");
      }
      deflateEnd(&zs);
    }
  }

  private bool initZStream () {
    import core.stdc.stdlib : malloc, free;
    if (mode == VFSZLibMode.Raw || pkb.ptr !is null) return true;
    // allocate buffer for packed data
    if (pkb.ptr is null) {
      auto pb = cast(ubyte*)malloc(obsize);
      if (pb is null) return false;
      pkb = pb[0..obsize];
    }
    zs.next_out = pkb.ptr;
    zs.avail_out = obsize;
    zs.next_in = null;
    zs.avail_in = 0;
    // initialize packer
    // -15 is a magic value used to decompress zip files:
    // it has the effect of not requiring the 2 byte header and 4 byte trailer
    if (deflateInit2(&zs, Z_BEST_COMPRESSION, Z_DEFLATED, (mode == VFSZLibMode.Zip ? -15 : 15), complevel, 0) != Z_OK) {
      free(pkb.ptr);
      pkb = null;
      eofhit = true;
      return false;
    }
    zs.next_out = pkb.ptr;
    zs.avail_out = obsize;
    zs.next_in = null;
    zs.avail_in = 0;
    // we are ready
    return true;
  }

  ssize read (void* buf, usize count) { pragma(inline, true); return -1; }

  ssize write (in void* buf, usize count) {
    if (buf is null) return -1;
    if (count == 0) return 0;
    if (mode == VFSZLibMode.Raw) {
      if (prpos != pos) return -1;
      zfl.seek(stpos+prpos);
      zfl.rawWriteExact(buf[0..count]);
      prpos += count;
      pos = prpos;
    } else {
      if (!initZStream()) return -1;
      auto css = count;
      auto bp = cast(const(ubyte)*)buf;
      while (css > 0) {
        zs.next_in = cast(typeof(zs.next_in))bp;
        zs.avail_in = (css > 0x3fff_ffff ? 0x3fff_ffff : cast(uint)css);
        bp += zs.avail_in;
        css -= zs.avail_in;
        // now process the whole input
        while (zs.avail_in > 0) {
          // write buffer
          //{ import core.stdc.stdio : printf; printf("writing %u bytes; avail_out: %u bytes\n", cast(uint)zs.avail_in, cast(uint)zs.avail_out); }
          if (zs.avail_out == 0) {
            if (prpos != pos) return -1;
            zfl.seek(stpos+prpos);
            zfl.rawWriteExact(pkb[0..obsize]);
            prpos += obsize;
            pos = prpos;
            zs.next_out = pkb.ptr;
            zs.avail_out = obsize;
          }
          auto err = deflate(&zs, Z_NO_FLUSH);
          if (err != Z_OK) return -1;
        }
      }
    }
    return count;
  }

  long lseek (long ofs, int origin) {
    if (!isOpen) return -1;
    //TODO: overflow checks
    switch (origin) {
      case Seek.Set: break;
      case Seek.Cur: ofs += prpos; break;
      case Seek.End: if (ofs > 0) ofs = 0; ofs += pos; break;
      default: return -1;
    }
    if (ofs < 0) return -1;
    if (ofs > pos) ofs = pos;
    prpos = ofs;
    return pos;
  }
}


/// wrap VFile into write-only zlib-packing stream.
/// default compression mode is 9.
public VFile wrapZLibStreamWO (VFile st, VFSZLibMode mode, int complevel=9, string fname=null) {
  return wrapStream(ZLibLowLevelWO(st, mode, complevel, fname), fname);
}

/// the same as previous function, but using VFSZLibMode.ZLib, as most people is using it
public VFile wrapZLibStreamWO (VFile st, int complevel=9, string fname=null) {
  return wrapZLibStreamWO(st, VFSZLibMode.ZLib, complevel, fname);
}


// ////////////////////////////////////////////////////////////////////////// //
/// wrap read-only memory buffer into VFile
public VFile wrapMemoryRO (const(void)[] buf, string fname=null) { return wrapStream(MemoryStreamRO(buf), fname); }

/// wrap read-write memory buffer into VFile; duplicates data
public VFile wrapMemoryRW (const(void)[] buf, string fname=null) { return wrapStream(MemoryStreamRW(buf), fname); }


// ////////////////////////////////////////////////////////////////////////// //
/// wrap libc stdout
public VFile wrapStdout () {
  static if (VFS_NORMAL_OS) {
    return VFile(1, false); // don't own
  } else {
    import core.stdc.stdio : stdout;
    if (stdout !is null) return VFile(stdout, false); // don't own
    return VFile.init;
  }
}

/// wrap libc stderr
public VFile wrapStderr () {
  static if (VFS_NORMAL_OS) {
    return VFile(2, false); // don't own
  } else {
    import core.stdc.stdio : stderr;
    if (stderr !is null) return VFile(stderr, false); // don't own
    return VFile.init;
  }
}

/// wrap libc stdin
public VFile wrapStdin () {
  static if (VFS_NORMAL_OS) {
    return VFile(0, false); // don't own
  } else {
    import core.stdc.stdio : stdin;
    if (stdin !is null) return VFile(stdin, false); // don't own
    return VFile.init;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/* handy building block for various unpackers/decoders
 * XPS API:
 *
 * XPS.InitUpkBufSize = initial size of intermediate "unpack buffer", which will be used
 *                      to store unpacked data chunks
 *
 *   -1 means "allocate as much as necessary" (with -upkbufsize as initial size)
 *    0 means "allocate as much as necessary" (with no initial allocation)
 *   >0 means "this is exact size, we will never need more than that"
 *
 * void setup (VFile fl, ulong agflags, long apos, long apksize, long aupksize);
 *   initialize decoder
 *     fl = input file; store it somewhere
 *     agflags = flags, decoder should know what they are for
 *     apos = encoded data offset in fl
 *     apksize = encoded data size
 *     aupksize = decoded data size
 *
 * void reset ();
 *   reset decoder; will be called when engine wants to start decoding again from apos
 *   should reset all necessary vars, etc.
 *
 * void close ();
 *   close fl, shutdown decoder, free memory, etc. nothing else will be called after this
 *
 * bool unpackChunk (VStreamDecoderLowLevelROPutBytesDg pdg);
 *   decode chunk of arbitrary size, use `putUnpackedBytes()` to put unpacked bytes into
 *   buffer. return `false` if EOF was hit, otherwise emit at least one byte.
 *   i.e. `unpackChunk()` can emit no bytes and return `true` to note that it can be called
 *   to get more data.
 *     pdg = delegate that should be called to emit decoded bytes
 */
public alias VStreamDecoderLowLevelROPutBytesDg = void delegate (const(ubyte)[] bts...) @trusted;

public struct VStreamDecoderLowLevelRO(XPS) {
private:
  static assert(XPS.InitUpkBufSize != int.min, "are you insane?");
  XPS epl;
  long size; // unpacked size
  long pos; // current file position
  long prpos; // previous file position
  bool eofhit;
  bool epleof;
  bool closed;
  static if (XPS.InitUpkBufSize <= 0) {
    size_t upkbuf; // ubyte*
    uint upkbufsize;
  } else {
    ubyte[XPS.InitUpkBufSize] upkbuf;
    enum upkbufsize = cast(uint)XPS.InitUpkBufSize;
  }
  uint upkbufused, upkbufpos;

public:
  this (VFile fl, ulong agflags, long aupsize, long astpos, long asize) {
    //debug(vfs_vfile_gc) { import core.stdc.stdio : printf; printf("upkbuf ofs=%u\n", (cast(uint)&upkbuf)-(cast(uint)&this)); }
    if (aupsize > uint.max) aupsize = uint.max;
    if (asize > uint.max) asize = uint.max;
    epl.setup(fl, agflags, astpos, cast(uint)asize, cast(uint)aupsize);
    epleof = eofhit = (aupsize == 0);
    size = aupsize;
    closed = !fl.isOpen;
    static if (XPS.InitUpkBufSize < 0) {
      if (!closed) {
        import core.stdc.stdlib : malloc;
        upkbuf = cast(ubyte*)malloc(-XPS.InitUpkBufSize);
        if (!upkbuf) throw new VFSException("out of memory");
        upkbufsize = -XPS.InitUpkBufSize;
      }
    }
  }

  @property bool isOpen () const pure nothrow @safe @nogc { pragma(inline, true); return !closed; }
  @property bool eof () const pure nothrow @safe @nogc { pragma(inline, true); return eofhit; }

  void close () {
    if (!closed) {
      //{ import core.stdc.stdio : printf; printf("CLOSED!\n"); }
      epleof = eofhit = true;
      closed = true;
      static if (XPS.InitUpkBufSize <= 0) {
        import core.stdc.stdlib : free;
        if (upkbuf) free(cast(void*)upkbuf);
        upkbuf = 0;
        upkbufsize = 0;
      }
      upkbufused = upkbufpos = 0;
      epl.close();
    }
  }

  private void reset () {
    upkbufused = 0;
    epl.reset();
  }

  private ssize doRealRead (void* buf, usize count) {
    if (count == 0) return 0; // the thing that should not be
    if (closed) return -1;
    auto dest = cast(ubyte*)buf;
    auto left = count;
    while (left > 0 && !closed) {
      // use the data that left from the unpacked chunk
      if (upkbufpos < upkbufused) {
        auto pkx = upkbufused-upkbufpos;
        if (pkx > left) pkx = cast(uint)left;
        static if (XPS.InitUpkBufSize <= 0) {
          dest[0..pkx] = (cast(ubyte*)upkbuf)[upkbufpos..upkbufpos+pkx];
        } else {
          dest[0..pkx] = upkbuf.ptr[upkbufpos..upkbufpos+pkx];
        }
        dest += pkx;
        upkbufpos += pkx;
        left -= pkx;
      } else {
        if (epleof) break;
        // no data in unpacked chunk, request new
        upkbufused = upkbufpos = 0;
        while (upkbufused == 0 && !closed && !epleof) {
          if (!epl.unpackChunk(&putUnpackedByte)) epleof = true;
        }
      }
    }
    return count-left;
  }

  ssize read (void* buf, usize count) {
    if (buf is null) return -1;
    if (count == 0 || size == 0) return 0;
    if (!isOpen) return -1; // read error
    if (count > ssize.max) count = ssize.max;
    if (size >= 0 && pos >= size) { eofhit = true; return 0; } // EOF
    // do we want to seek backward?
    if (prpos > pos) {
      // yes, rewind
      reset();
      epleof = eofhit = (size == 0);
      prpos = 0;
    }
    // do we need to seek forward?
    if (prpos < pos) {
      // yes, skip data
      ubyte[512] tmp = 0;
      while (prpos < pos) {
        auto xrd = pos-prpos;
        auto rd = doRealRead(tmp.ptr, cast(uint)(xrd > tmp.length ? tmp.length : xrd));
        if (rd <= 0) return -1;
        prpos += rd;
      }
      if (prpos != pos) return -1;
    }
    assert(prpos == pos);
    // unpack data
    if (size >= 0 && size-pos < count) {
      count = cast(usize)(size-pos);
      if (count == 0) return 0;
      if (count > ssize.max) count = ssize.max;
    }
    auto rd = doRealRead(buf, count);
    pos = (prpos += rd);
    return rd;
  }

  ssize write (in void* buf, usize count) { pragma(inline, true); return -1; }

  long lseek (long ofs, int origin) {
    if (!isOpen) return -1;
    //TODO: overflow checks
    switch (origin) {
      case Seek.Set: break;
      case Seek.Cur: ofs += pos; break;
      case Seek.End:
        if (ofs > 0) ofs = 0;
        ofs += size;
        break;
      default:
        return -1;
    }
    if (ofs < 0) return -1;
    eofhit = (size >= 0 && ofs >= size);
    pos = ofs;
    return pos;
  }

private:
  void putUnpackedByte (const(ubyte)[] bts...) @trusted {
    //{ import core.stdc.stdio : printf; printf("putUnpackedByte: %u; upkbufused=%u; upkbufsize=%u\n", cast(uint)bts.length, upkbufused, upkbufsize); }
    if (closed) return; // just in case
    foreach (ubyte b; bts[]) {
      static if (XPS.InitUpkBufSize <= 0) {
        if (upkbufused >= upkbufsize) {
          // allocate more memory for unpacked data buffer
          import core.stdc.stdlib : realloc;
          auto newsz = (upkbufsize ? upkbufsize*2 : 256*1024);
          if (newsz <= upkbufsize) throw new Exception("out of memory");
          auto nbuf = cast(size_t)realloc(cast(void*)upkbuf, newsz);
          if (!nbuf) throw new Exception("out of memory");
          upkbuf = nbuf;
          upkbufsize = newsz;
          //{ import core.stdc.stdio : printf; printf("  grow: upkbufsize=%u\n", upkbufsize); }
        }
        //assert(upkbufused < upkbufsize);
        //assert(upkbuf);
        (cast(ubyte*)upkbuf)[upkbufused++] = b;
      } else {
        if (upkbufused >= upkbuf.length) throw new Exception("out of unpack buffer");
        upkbuf.ptr[upkbufused++] = b;
      }
    }
  }
}
