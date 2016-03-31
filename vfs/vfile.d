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
  @property const(char)[] name () { return null; }
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
  override @property bool isOpen () { return (fl !is null); }
  override @property bool eof () { return (fl is null || core.stdc.stdio.feof(fl) != 0); }

  override void close () {
    if (fl !is null) {
      import std.exception : ErrnoException;
      auto res = core.stdc.stdio.fclose(fl);
      fl = null;
      if (res != 0) throw new ErrnoException("can't close file", __FILE__, __LINE__);
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
    auto res = core.sys.posix.stdio.fseeko(fl, offset, origin);
    if (res != -1) core.stdc.stdio.clearerr(fl);
    return core.sys.posix.stdio.ftello(fl);
  }
}


usize WrapLibcFile (core.stdc.stdio.FILE* fl) {
  return newWS!WrappedStreamLibcFile(fl);
}


// ////////////////////////////////////////////////////////////////////////// //
final class WrappedStreamFD : WrappedStreamRC {
private:
  int fd;

  public this (int afd) { fd = afd; eofhit = (afd < 0); } // fuck! emplace needs it

protected:
  override @property bool isOpen () { return (fd >= 0); }

  override void close () {
    if (fd >= 0) {
      import std.exception : ErrnoException;
      auto res = core.sys.posix.unistd.close(fd);
      fd = -1;
      eofhit = true;
      if (res < 0) throw new ErrnoException("can't close file", __FILE__, __LINE__);
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


usize WrapFD (int fd) {
  return newWS!WrappedStreamFD(fd);
}


// ////////////////////////////////////////////////////////////////////////// //
final class WrappedStreamAny(ST) : WrappedStreamRC {
private:
  ST st;
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

  override @property bool isOpen () {
    static if (streamHasIsOpen!ST) {
      if (closed) return true;
      return st.isOpen;
    } else {
      return !closed;
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


// ////////////////////////////////////////////////////////////////////////// //
private struct PartialLowLevelRO {
  VFile zfl; // original file
  long stpos; // starting position
  long size; // unpacked size
  long pos; // current file position
  bool eofhit;

  this (VFile fl, long astpos, long asize) {
    stpos = astpos;
    size = asize;
    zfl = fl;
  }

  //@property const(char)[] name () { pragma(inline, true); return zfl.name; }
  @property bool isOpen () { pragma(inline, true); return zfl.isOpen; }
  @property bool eof () { pragma(inline, true); return eofhit; }

  void close () {
    eofhit = true;
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
public VFile wrapStreamRO (VFile st, long stpos=0, long len=-1) {
  if (stpos < 0) throw new VFSException("invalid starting position");
  if (len == -1) len = st.size-stpos;
  if (len < 0) throw new VFSException("invalid length");
  return wrapStream(PartialLowLevelRO(st, stpos, len));
}


// ////////////////////////////////////////////////////////////////////////// //
public enum VFSZLibMode {
  Raw,
  ZLib,
  Zip, // special mode for zip archives
}


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

  this (VFile fl, VFSZLibMode amode, long aupsize, long astpos, long asize) {
    zfl = fl;
    stpos = astpos;
    size = aupsize;
    pksize = asize;
    mode = amode;
  }

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

  private bool initZStream () {
    import core.stdc.stdlib : malloc, free;
    if (mode == VFSZLibMode.Raw || pkb.ptr !is null) return true;
    // allocate buffer for packed data
    auto pb = cast(ubyte*)malloc(ibsize);
    if (pb is null) return false;
    pkb = pb[0..ibsize];
    zs.avail_in = 0;
    zs.avail_out = 0;
    // initialize unpacker
    // -15 is a magic value used to decompress zip files:
    // it has the effect of not requiring the 2 byte header and 4 byte trailer
    if (inflateInit2(&zs, (mode == VFSZLibMode.Zip ? -15 : 15)) != Z_OK) {
      free(pb);
      pkb = null;
      return false;
    }
    // we are ready
    return true;
  }

  private bool readPackedChunk () {
    import core.stdc.stdio : fread;
    import core.sys.posix.stdio : fseeko;
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
      if (eoz) return false;
      if (!readPackedChunk()) return false;
      auto err = inflate(&zs, Z_SYNC_FLUSH);
      //if (err == Z_BUF_ERROR) { import iv.writer; writeln("*** OUT OF BUFFER!"); }
      if (err != Z_STREAM_END && err != Z_OK) return false;
      if (err == Z_STREAM_END) eoz = true;
    }
    return true;
  }

  ssize read (void* buf, usize count) {
    if (buf is null) return -1;
    if (count == 0 || size == 0) return 0;
    if (!isOpen) return -1; // read error
    if (pos >= size) { eofhit = true; return 0; } // EOF
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
        if (!initZStream()) return -1;
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
      if (size-pos < count) { eofhit = true; count = cast(usize)(size-pos); }
      zs.next_out = cast(typeof(zs.next_out))buf;
      zs.avail_out = cast(uint)count;
      if (!unpackNextChunk()) return -1;
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
        ofs += size;
        break;
      default:
        return -1;
    }
    if (ofs < 0) return -1;
    if (ofs > size) ofs = size;
    pos = ofs;
    eofhit = false;
    return pos;
  }
}


/// wrap VFile into read-only zlib-packed stream, with given offset and length.
/// if `len` == -1, wrap from starting position to file end.
/// `upsize`: size of unpacked file (sorry, should be known)
public VFile wrapZLibStreamRO (VFile st, VFSZLibMode mode, long upsize, long stpos=0, long len=-1) {
  if (stpos < 0) throw new VFSException("invalid starting position");
  if (upsize < 0) throw new VFSException("invalid unpacked size");
  if (len == -1) len = st.size-stpos;
  if (len < 0) throw new VFSException("invalid length");
  return wrapStream(ZLibLowLevelRO(st, mode, upsize, stpos, len));
}
