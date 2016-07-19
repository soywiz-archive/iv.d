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
// severely outdated ZIP archive interface
// use iv.vfs instead
module iv.ziparcstm is aliced;

import iv.stream;


// ////////////////////////////////////////////////////////////////////////// //
abstract class ArchiveFile {
public:
  // mNormNames: `true` for convert names to lower case, do case-insensitive comparison (ASCII only)

  static auto opCall(T) (T fname, bool normNames=true) if (is(T : const(char)[])) {
    import std.stdio : File;
    static if (is(T == string)) {
      auto fl = File(fname);
    } else {
      auto fl = File(fname.idup); // alas
    }
    return new ZipArchiveImpl!(typeof(fl))(fl, normNames);
  }

  // this will make a copy of `st`
  static auto opCall(ST) (auto ref ST st, bool normNames=true) if (isReadableStream!ST && isSeekableStream!ST && streamHasSize!ST) {
    return new ZipArchiveStream!ST(st, normNames);
  }

protected:
  import core.sys.posix.sys.types : ssize_t, off64_t = off_t;

  static struct FileInfo {
    bool packed; // only "store" and "deflate" are supported
    ulong pksize;
    ulong size;
    ulong hdrofs;
    string path;
    string name;
  }

  // for dir range
  public static struct DirEntry {
    string path;
    string name;
    ulong size;
  }

protected:
  FileInfo[] dir;
  bool mNormNames; // true: convert names to lower case, do case-insensitive comparison (ASCII only)

protected:
  // ////////////////////////////////////////////////////////////////////// //
  static import core.sync.mutex;

  core.sync.mutex.Mutex lock;

  void initLock () {
    lock = new core.sync.mutex.Mutex;
  }

public:
  abstract @property bool isOpen () nothrow;
  abstract ssize_t read (void* buf, usize count) nothrow;
  abstract long seek (long ofs, int whence=0) nothrow;
  abstract int close () nothrow;

  final @property auto files () {
    static struct Range {
    private:
      ArchiveFile me;
      ulong curindex;

    nothrow @safe @nogc:
      this (ArchiveFile ame, ulong aidx=0) { me = ame; curindex = aidx; }

    public:
      @property bool empty () const { return (curindex >= me.dir.length); }
      @property DirEntry front () const {
        return DirEntry(
          (curindex < me.dir.length ? me.dir[cast(usize)curindex].path : null),
          (curindex < me.dir.length ? me.dir[cast(usize)curindex].name : null),
          (curindex < me.dir.length ? me.dir[cast(usize)curindex].size : 0));
      }
      @property Range save () { return Range(me, curindex); }
      void popFront () { if (curindex < me.dir.length) ++curindex; }
      @property ulong length () const { return me.dir.length; }
      @property ulong position () const { return curindex; } // current position
      @property void position (ulong np) { curindex = np; }
      void rewind () { curindex = 0; }
    }
    return Range(this);
  }

  auto fopen (ref in DirEntry de) {
    static bool strequ() (const(char)[] s0, const(char)[] s1) {
      if (s0.length != s1.length) return false;
      foreach (immutable idx, char ch; s0) {
        char c1 = s1[idx];
        if (ch >= 'A' && ch <= 'Z') ch += 32; // poor man's `toLower()`
        if (c1 >= 'A' && c1 <= 'Z') c1 += 32; // poor man's `toLower()`
        if (ch != c1) return false;
      }
      return true;
    }

    foreach (immutable idx, ref fi; dir) {
      if (mNormNames) {
        if (strequ(fi.path, de.path) && strequ(fi.name, de.name)) return InnerFileStream(this, idx, fi.name);
      } else {
        if (fi.path == de.path && fi.name == de.name) return InnerFileStream(this, idx, fi.name);
      }
    }

    throw new NamedException!"ZipArchive"("file not found");
  }

  auto fopen (const(char)[] fname) {
    DirEntry de;
    auto pos = fname.length;
    while (pos > 0 && fname[pos-1] != '/') --pos;
    if (pos) {
      de.path = cast(string)fname[0..pos]; // it's safe here
      de.name = cast(string)fname[pos..$]; // it's safe here
    } else {
      de.name = cast(string)fname; // it's safe here
    }
    return fopen(de);
  }

  // we might want to return the same file struct for disk and archived files
  static auto fopenDisk(T) (T fname) if (is(T : const(char)[])) { return InnerFileStream(fname); }

private:
  // ////////////////////////////////////////////////////////////////////// //
  static private struct InnerFileStream {
  public:
    import core.stdc.stdio : SEEK_SET, SEEK_CUR, SEEK_END;

    string name;

  private:
    InnerFileCookied mStData;

    this(T) (T filename) if (is(T : const(char)[])) {
      import core.sys.linux.stdio : fopencookie;
      import core.stdc.stdio : FILE;
      import core.stdc.stdio : fopen, fclose, fseek, ftell;
      import core.stdc.stdlib : calloc, free;
      import etc.c.zlib;
      import std.internal.cstring : tempCString;
      import core.memory : GC;

      // open disk file
      FILE* fl = fopen(filename.tempCString!char(), "rb");
      if (fl is null) throw new NamedException!"ZipArchive"("can't open file '"~filename.idup~"'");
      scope(failure) fclose(fl);
      // get size
      if (fseek(fl, 0, SEEK_END) < 0) throw new NamedException!"ZipArchive"("can't get file size for '"~filename.idup~"'");
      auto sz = ftell(fl);
      if (sz == -1) throw new NamedException!"ZipArchive"("can't get file size for '"~filename.idup~"'");
      if (sz > 0xffff_ffff) throw new NamedException!"ZipArchive"("file '"~filename.idup~"' too big");

      this.initialize(); // fills mStData
      mStData.stpos = 0;
      mStData.size = cast(uint)sz;
      mStData.pksize = 0;
      mStData.mode = InnerFileCookied.Mode.Raw;
      mStData.fl = fl;
      // ok
      mStData.initialize();
      static if (is(T == string)) {
        name = filename;
      } else {
        name = filename.idup;
      }
    }

    this(T) (ArchiveFile za, uint idx, T filename) if (is(T : const(char)[])) {
      import core.sys.linux.stdio : fopencookie;
      import core.stdc.stdio : FILE;
      import core.stdc.stdio : fopen, fclose, fseek, ftell;
      import core.stdc.stdlib : calloc, free;
      import etc.c.zlib;
      import std.internal.cstring : tempCString;
      import core.memory : GC;

      assert(za !is null);
      if (!za.isOpen) throw new NamedException!"ZipArchive"("archive wasn't opened");
      //if (zfl.name.length == 0) throw new NamedException!"ZipArchive"("archive has no name");
      if (idx >= za.dir.length) throw new NamedException!"ZipArchive"("invalid dir index");
      ulong stofs;
      {
        za.lock.lock();
        scope(exit) za.lock.unlock();
        // read file header
        ZipFileHeader zfh = void;
        if (za.seek(za.dir[idx].hdrofs) == -1) throw new NamedException!"ZipArchive"("seek error");
        if (za.read(&zfh, zfh.sizeof) != zfh.sizeof) throw new NamedException!"ZipArchive"("reading error");
        if (zfh.sign != "PK\x03\x04") throw new NamedException!"ZipArchive"("invalid archive entry");
        // skip name and extra
        auto xpos = za.seek(0, SEEK_CUR);
        if (xpos == -1) throw new NamedException!"ZipArchive"("seek error");
        stofs = xpos+zfh.namelen+zfh.extlen;
      }

      this.initialize(); // fills mStData
      mStData.stpos = stofs;
      mStData.size = cast(uint)za.dir[idx].size; //FIXME
      mStData.pksize = cast(uint)za.dir[idx].pksize; //FIXME
      mStData.mode = (za.dir[idx].packed ? InnerFileCookied.Mode.Zip : InnerFileCookied.Mode.Raw);
      mStData.za = za;
      mStData.lock = za.lock;
      // ok
      mStData.initialize();
      static if (is(T == string)) {
        name = filename;
      } else {
        name = filename.idup;
      }
    }

    private void initialize () {
      // and now... rock-a-rolla!
      // actually, we shouldn't use malloc() here, 'cause we can have alot of
      // free memory in GC and no memory for malloc(), but... let's be realistic:
      // we aren't aiming at constrained systems
      import core.exception : onOutOfMemoryErrorNoGC;
      import core.memory : GC;
      import core.stdc.stdlib : malloc;
      import std.conv : emplace;
      import std.traits : hasIndirections;
      alias CT = InnerFileCookied; // i'm lazy
      enum instSize = __traits(classInstanceSize, CT);
      // let's hope that malloc() aligns returned memory right
      auto mem = malloc(instSize);
      if (mem is null) onOutOfMemoryErrorNoGC(); // oops
      usize root = cast(usize)mem;
      /*
      static if (hasIndirections!ST) {
        // ouch, ST has some pointers; register it as gc root and range
        // note that this approach is very simplictic; we might want to
        // scan the type for pointers using typeinfo pointer bitmap and
        // register only pointer containing areas.
        GC.addRoot(cast(void*)root);
        GC.addRange(cast(void*)root, instSize);
        enum isrng = true;
      } else {
        enum isrng = false;
      }
      */
      enum isrng = true;
      mStData = emplace!CT(mem[0..instSize], root, isrng);
    }

  public:
    this (this) @safe nothrow @nogc { if (isOpen) mStData.incRef(); }
    ~this () { close(); }

    void opAssign() (auto ref InnerFileStream src) {
      if (isOpen) {
        // assigning to opened stream
        if (src.isOpen) {
          // both streams are opened
          // we don't care if internal streams are different, our rc scheme will take care of this
          auto old = mStData; // decRef() can throw, so be on the safe side
          mStData = src.mStData;
          mStData.incRef(); // this can't throw
          old.decRef(); // release old stream
        } else {
          // just close this one
          close();
        }
      } else if (src.isOpen) {
        // this stream is closed, but other is open; easy deal
        mStData = src.mStData;
        mStData.incRef();
      }
      name = src.name;
    }

    @property bool isOpen () const pure nothrow @safe @nogc { pragma(inline, true); return (mStData !is null); }

    void close () {
      if (isOpen) {
        mStData.decRef();
        mStData = null;
        name = null;
      }
    }

    @property long tell () const pure nothrow @safe @nogc { pragma(inline, true); return (isOpen ? mStData.pos : 0); }
    @property long size () const pure nothrow @safe @nogc { pragma(inline, true); return (isOpen ? mStData.size : 0); }
    @property bool eof () const pure nothrow @trusted @nogc { pragma(inline, true); return (isOpen ? mStData.pos >= mStData.size : true); }

    //TODO: check for overflow
    void seek (long offset, int origin=SEEK_SET) @trusted {
      if (!isOpen) throw new NamedException!"ZipArchive"("can't seek in closed stream");
      if (mStData.seek(offset, origin) < 0) throw new NamedException!"ZipArchive"("seek error");
    }

    private import std.traits : isMutable;

    T[] rawRead(T) (T[] buf) @trusted if (isMutable!T) {
      if (!isOpen) throw new NamedException!"ZipArchive"("can't read from closed stream");
      if (buf.length > 0) {
        auto vb = cast(void[])buf;
        auto len = mStData.read(vb.ptr, vb.length);
        return buf[0..cast(usize)len/T.sizeof];
      } else {
        return buf[0..0];
      }
    }
  }

  static assert(isReadableStream!InnerFileStream);
  static assert(isSeekableStream!InnerFileStream);
  static assert(streamHasEOF!InnerFileStream);
  static assert(streamHasSeek!InnerFileStream);
  static assert(streamHasTell!InnerFileStream);
  static assert(streamHasName!InnerFileStream);
  static assert(streamHasSize!InnerFileStream);

  // ////////////////////////////////////////////////////////////////////// //
  // "inner" file processor; processes both packed and unpacked files
  // can be used as normal disk file processor too
  static private final class InnerFileCookied {
    private import etc.c.zlib;
    private import core.sys.posix.sys.types : ssize_t, off64_t = off_t;
    private import core.stdc.stdio : FILE;

    uint rc = 1;
    immutable bool gcrange; // do `GC.removeRange()`?
    usize gcroot; // allocated memory that must be free()d

    enum ibsize = 32768;

    enum Mode { Raw, ZLib, Zip }

    core.sync.mutex.Mutex lock;
    bool killLock;
    // note that either one of `fl` or `xfl` must be opened and operational
    FILE* fl; // disk file, can be `null`
    ArchiveFile za; // archive file, can be closed
    Mode mode;
    long stpos; // starting position
    uint size; // unpacked size
    uint pksize; // packed size
    uint pos; // current file position
    uint prpos; // previous file position
    uint pkpos; // current position in DAT
    ubyte[] pkb; // packed data
    z_stream zs;
    bool eoz;

    this (usize agcroot, bool arange) nothrow @safe @nogc {
      gcrange = arange;
      gcroot = agcroot;
      //{ import std.stdio; stderr.writefln("0x%08x: ctor, rc=%s", gcroot, rc); }
    }

    // this should never be called
    ~this () nothrow @safe @nogc {
      if (rc != 0) assert(0); // the thing that should not be
      assert(0); // why we are here?!
    }

    void incRef () nothrow @safe @nogc {
      if (++rc == 0) assert(0); // hey, this is definitely a bug!
      //{ import std.stdio; stderr.writefln("0x%08x: incRef, rc=%s", gcroot, rc); }
    }

    // return true if this class is dead
    bool decRef () {
      if (rc-- == 0) assert(0); // hey, this is definitely a bug!
      //{ import std.stdio; stderr.writefln("0x%08x: decRef, rc=%s", gcroot, rc); }
      if (rc == 0) {
        import core.memory : GC;
        import core.stdc.stdlib : free;
        close(); // finalize stream
        if (gcroot == 0) assert(0); // the thing that should not be
        // remove roots
        if (gcrange) {
          GC.removeRange(cast(void*)gcroot);
          GC.removeRoot(cast(void*)gcroot);
        }
        // free allocated memory
        free(cast(void*)gcroot);
        // just in case
        //{ import std.stdio; stderr.writefln("0x%08x: dead, rc=%s", gcroot, rc); }
        gcroot = 0;
        return true;
      } else {
        return false;
      }
    }

  nothrow:
    @property bool isOpen () { return (fl !is null || (za !is null && za.isOpen)); }

    void initialize () {
      if (lock is null) {
        import core.memory : GC;
        lock = new core.sync.mutex.Mutex;
        GC.addRoot(*cast(void**)&lock);
        killLock = true;
      }
    }

    void close () {
      import core.memory : GC;
      import core.stdc.stdlib : free;
      {
        //if (lock !is null) { import iv.writer; writeln("CLOSING!"); }
        if (lock !is null) lock.lock();
        scope(exit) if (lock !is null) lock.unlock();
        if (pkb.length) {
          inflateEnd(&zs);
          free(pkb.ptr);
          pkb = null;
        }
        if (fl !is null) {
          import core.stdc.stdio : fclose;
          fclose(fl);
          fl = null;
        }
        za = null;
      }
      eoz = true;
      if (lock !is null && killLock) {
        GC.removeRoot(*cast(void**)&lock);
        delete lock;
        lock = null;
        killLock = false;
      }
    }

    private bool initZStream () {
      import core.stdc.stdlib : malloc, free;
      if (mode == Mode.Raw || pkb.ptr !is null) return true;
      // allocate buffer for packed data
      auto pb = cast(ubyte*)malloc(ibsize);
      if (pb is null) return false;
      pkb = pb[0..ibsize];
      zs.avail_in = 0;
      zs.avail_out = 0;
      // initialize unpacker
      // -15 is a magic value used to decompress zip files:
      // it has the effect of not requiring the 2 byte header and 4 byte trailer
      if (inflateInit2(&zs, (mode == Mode.Zip ? -15 : 15)) != Z_OK) {
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
      if (fl !is null) {
        // `FILE*`
        if (fseeko(fl, stpos+pkpos, 0) < 0) return false;
        if (fread(pkb.ptr, zs.avail_in, 1, fl) != 1) return false;
      } else if (za !is null) {
        if (za.seek(stpos+pkpos, 0) == -1) return false;
        auto rd = za.read(pkb.ptr, zs.avail_in);
        if (rd != zs.avail_in) return false;
      } else {
        return false;
      }
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

    ssize_t read (void* buf, usize count) nothrow {
      if (buf is null) return -1;
      if (count == 0 || size == 0) return 0;
      lock.lock();
      scope(exit) lock.unlock();
      if (!isOpen) return -1; // read error
      if (pos >= size) return 0; // EOF
      if (mode == Mode.Raw) {
        import core.stdc.stdio : ferror, fread;
        import core.sys.posix.stdio : fseeko;
        if (size-pos < count) count = cast(usize)(size-pos);
        if (fl !is null) {
          // `FILE*`
          if (fseeko(fl, stpos+pos, 0) < 0) return -1;
          auto rd = fread(buf, 1, count, fl);
          if (rd != count && (rd < 0 || ferror(fl))) rd = -1;
          if (rd > 0) pos += rd;
          return rd;
        } else if (za !is null) {
          if (za.seek(stpos+pos, 0) == -1) return -1;
          auto rd = za.read(buf, count);
          if (rd < 1) return -1;
          pos += rd;
          return (rd == count ? rd : -1);
        } else {
          return -1;
        }
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
          uint skp = pos-prpos;
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
        if (size-pos < count) count = cast(usize)(size-pos);
        zs.next_out = cast(typeof(zs.next_out))buf;
        zs.avail_out = cast(uint)count;
        if (!unpackNextChunk()) return -1;
        prpos = (pos += count);
        return count;
      }
    }

    long seek (long ofs, int whence) nothrow {
      lock.lock();
      scope(exit) lock.unlock();
      if (!isOpen) return -1;
      //TODO: overflow checks
      switch (whence) {
        case 0: // SEEK_SET
          break;
        case 1: // SEEK_CUR
          ofs += pos;
          break;
        case 2: // SEEK_END
          if (ofs > 0) ofs = 0;
          ofs += size;
          break;
        default:
          return -1;
      }
      if (ofs < 0) return -1;
      if (ofs > size) ofs = size;
      pos = cast(uint)ofs;
      return ofs;
    }
  }

static protected:
  T[] xalloc(T) (usize len) {
    import core.stdc.stdlib : malloc;
    if (len < 1) return null;
    auto res = cast(T*)malloc(len*T.sizeof);
    if (res is null) {
      import core.exception : onOutOfMemoryErrorNoGC;
      onOutOfMemoryErrorNoGC();
    }
    res[0..len] = T.init;
    return res[0..len];
  }

  void xfree(T) (ref T[] slc) {
    if (slc.ptr !is null) {
      import core.stdc.stdlib : free;
      free(slc.ptr);
    }
    slc = null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private class ZipArchiveImpl(ST) : ArchiveFile if (isReadableStream!ST && isSeekableStream!ST && streamHasSize!ST) {
private final:
  static if (!streamHasIsOpen!ST) bool flopened;
  ST zfl;

public:
  this () { assert(0); }

  // it now owns the file (if no exception was thrown)
  this() (auto ref ST fl, bool normNames) {
    mNormNames = normNames;
    initLock();
    open(fl);
    scope(success) {
      zfl = fl;
      static if (!streamHasIsOpen!ST) flopened = true;
    }
  }

  override @property bool isOpen () nothrow {
    static if (streamHasIsOpen!ST) {
      try {
        return zfl.isOpen;
      } catch (Exception) {}
      return false;
    } else {
      return flopened;
    }
  }

  override ssize_t read (void* buf, usize count) nothrow {
    if (!isOpen) return -1;
    if (count == 0) return 0;
    try {
      auto res = zfl.rawRead(buf[0..count]);
      return cast(ssize_t)res.length;
    } catch (Exception) {
      return -1;
    }
  }

  override long seek (long ofs, int whence=0) nothrow {
    if (!isOpen) return -1;
    try {
      zfl.seek(ofs, whence);
      return zfl.tell;
    } catch (Exception) {
      return -1;
    }
  }

  override int close () nothrow {
    if (!isOpen) return 0;
    try {
      static if (isCloseableStream!ST) zfl.close();
      return 0;
    } catch (Exception) {
      return -1;
    }
  }

private:
  void cleanup () {
    dir.length = 0;
  }

  void open() (auto ref ST fl) {
    import core.stdc.stdio : SEEK_CUR, SEEK_END;
    debug import std.stdio : writeln, writefln;
    scope(failure) cleanup();

    /*
    ushort readU16 () {
      ubyte[2] data;
      if (fl.rawRead(data[]).length != data.length) throw new NamedException!"ZipArchive"("reading error");
      return cast(ushort)(data[0]+0x100*data[1]);
    }
    */

    if (fl.size > 0xffff_ffffu) throw new NamedException!"ZipArchive"("file too big");
    ulong flsize = fl.size;
    if (flsize < EOCDHeader.sizeof) throw new NamedException!"ZipArchive"("file too small");

    // search for "end of central dir"
    auto cdbuf = xalloc!ubyte(65536+EOCDHeader.sizeof+Z64Locator.sizeof);
    scope(exit) xfree(cdbuf);
    ubyte[] buf;
    ulong ubufpos;
    if (flsize < cdbuf.length) {
      fl.seek(0);
      buf = fl.rawRead(cdbuf[0..cast(usize)flsize]);
      if (buf.length != flsize) throw new NamedException!"ZipArchive"("reading error");
    } else {
      fl.seek(-cast(ulong)cdbuf.length, SEEK_END);
      ubufpos = fl.tell;
      buf = fl.rawRead(cdbuf[]);
      if (buf.length != cdbuf.length) throw new NamedException!"ZipArchive"("reading error");
    }
    int pos;
    for (pos = cast(int)(buf.length-EOCDHeader.sizeof); pos >= 0; --pos) {
      if (buf[pos] == 'P' && buf[pos+1] == 'K' && buf[pos+2] == 5 && buf[pos+3] == 6) break;
    }
    if (pos < 0) throw new NamedException!"ZipArchive"("no central dir end marker found");
    auto eocd = cast(EOCDHeader*)&buf[pos];
    debug(ziparc) {
      writeln("=== EOCD ===");
      writeln("diskno: ", eocd.diskno);
      writeln("diskcd: ", eocd.diskcd);
      writeln("diskfileno: ", eocd.diskfileno);
      writeln("fileno: ", eocd.fileno);
      writeln("cdsize: ", eocd.cdsize);
      writefln("cdofs: %s (0x%08x)", eocd.cdofs, eocd.cdofs);
      writeln("cmtsize: ", eocd.cmtsize);
    }
    long cdofs = -1, cdsize = -1;
    bool zip64 = false;
    // zip64?
    if (eocd.cdofs == 0xffff_ffffu) {
      zip64 = true;
      if (pos < Z64Locator.sizeof) throw new NamedException!"ZipArchive"("corrupted archive");
      auto lt64 = cast(Z64Locator*)&buf[pos-Z64Locator.sizeof];
      if (lt64.sign != "PK\x06\x07") throw new NamedException!"ZipArchive"("corrupted archive");
      if (lt64.diskcd != 0 || lt64.diskno > 1) throw new NamedException!"ZipArchive"("multidisk archive");
      debug writeln("ecd64ofs=", lt64.ecd64ofs);
      if (lt64.ecd64ofs < 0 || lt64.ecd64ofs+EOCD64Header.sizeof > ubufpos+pos-Z64Locator.sizeof) throw new NamedException!"ZipArchive"("corrupted archive");
      EOCD64Header e64 = void;
      fl.seek(lt64.ecd64ofs);
      if (fl.rawRead((&e64)[0..1]).length != 1) throw new NamedException!"ZipArchive"("reading error");
      if (e64.sign != "PK\x06\x06") throw new NamedException!"ZipArchive"("corrupted archive");
      if (e64.diskno != 0 || e64.diskcd != 0) throw new NamedException!"ZipArchive"("multidisk archive");
      if (e64.diskfileno != e64.fileno) throw new NamedException!"ZipArchive"("corrupted archive");
      if (e64.cdsize >= lt64.ecd64ofs) throw new NamedException!"ZipArchive"("corrupted archive");
      if (e64.cdofs >= lt64.ecd64ofs || e64.cdofs+e64.cdsize > lt64.ecd64ofs) throw new NamedException!"ZipArchive"("corrupted archive");
      cdofs = e64.cdofs;
      cdsize = e64.cdsize;
    } else {
      if (eocd.diskno != 0 || eocd.diskcd != 0) throw new NamedException!"ZipArchive"("multidisk archive");
      if (eocd.diskfileno != eocd.fileno || ubufpos+pos+EOCDHeader.sizeof+eocd.cmtsize != flsize) throw new NamedException!"ZipArchive"("corrupted archive");
      cdofs = eocd.cdofs;
      cdsize = eocd.cdsize;
      if (cdofs >= ubufpos+pos || flsize-cdofs < cdsize) throw new NamedException!"ZipArchive"("corrupted archive");
    }

    // now read central directory
    auto namebuf = xalloc!char(0x10000);
    scope(exit) xfree(namebuf);

    uint[string] knownNames; // value is dir index
    scope(exit) knownNames.destroy;
    cleanup();
    auto bleft = cdsize;
    fl.seek(cdofs);
    CDFileHeader cdfh = void;
    char[4] sign;
    dir.assumeSafeAppend; // yep
    while (bleft > 0) {
      if (bleft < 4) break;
      if (fl.rawRead(sign[]).length != sign.length) throw new NamedException!"ZipArchive"("reading error");
      bleft -= 4;
      if (sign[0] != 'P' || sign[1] != 'K') throw new NamedException!"ZipArchive"("invalid central directory entry");
      // digital signature?
      if (sign[2] == 5 && sign[3] == 5) {
        // yes, skip it
        if (bleft < 2) throw new NamedException!"ZipArchive"("reading error");
        auto sz = fl.readNum!ushort;
        if (sz > bleft) throw new NamedException!"ZipArchive"("invalid central directory entry");
        fl.seek(sz, SEEK_CUR);
        bleft -= sz;
        continue;
      }
      // file item?
      if (sign[2] == 1 && sign[3] == 2) {
        if (bleft < cdfh.sizeof) throw new NamedException!"ZipArchive"("reading error");
        if (fl.rawRead((&cdfh)[0..1]).length != 1) throw new NamedException!"ZipArchive"("reading error");
        bleft -= cdfh.sizeof;
        if (cdfh.disk != 0) throw new NamedException!"ZipArchive"("invalid central directory entry (disk number)");
        if (bleft < cdfh.namelen+cdfh.extlen+cdfh.cmtlen) throw new NamedException!"ZipArchive"("invalid central directory entry");
        // skip bad files
        if ((cdfh.method != 0 && cdfh.method != 8) || cdfh.namelen == 0 || (cdfh.gflags&0b10_0000_0110_0001) != 0 || (cdfh.attr&0x58) != 0 ||
            cast(long)cdfh.hdrofs+(cdfh.method ? cdfh.pksize : cdfh.size) >= ubufpos+pos)
        {
          // ignore this
          fl.seek(cdfh.namelen+cdfh.extlen+cdfh.cmtlen, SEEK_CUR);
          bleft -= cdfh.namelen+cdfh.extlen+cdfh.cmtlen;
          continue;
        }
        FileInfo fi;
        fi.packed = (cdfh.method != 0);
        fi.pksize = cdfh.pksize;
        fi.size = cdfh.size;
        fi.hdrofs = cdfh.hdrofs;
        if (!fi.packed) fi.pksize = fi.size;
        // now, this is valid file, so read it's name
        if (fl.rawRead(namebuf[0..cdfh.namelen]).length != cdfh.namelen) throw new NamedException!"ZipArchive"("reading error");
        auto nb = new char[](cdfh.namelen);
        uint nbpos = 0;
        uint lastSlash = 0;
        foreach (ref char ch; namebuf[0..cdfh.namelen]) {
          if (ch == '\\') ch = '/'; // just in case
          if (ch == '/' && (nbpos == 0 || (nbpos > 0 && nb[nbpos-1] == '/'))) continue;
          if (ch == '/') lastSlash = nbpos+1;
          if (mNormNames && ch >= 'A' && ch <= 'Z') ch += 32; // poor man's `toLower()`
          nb[nbpos++] = ch;
        }
        bool doSkip = false;
        // should we parse extra field?
        debug writefln("size=0x%08x; pksize=0x%08x; packed=%s", fi.size, fi.pksize, (fi.packed ? "tan" : "ona"));
        if (zip64 && (fi.size == 0xffff_ffffu || fi.pksize == 0xffff_ffffu || fi.hdrofs == 0xffff_ffffu)) {
          // yep, do it
          bool found = false;
          //Z64Extra z64e = void;
          debug writeln("extlen=", cdfh.extlen);
          while (cdfh.extlen >= 4) {
            auto eid = fl.readNum!ushort;
            auto esize = fl.readNum!ushort;
            debug writefln("0x%04x %s", eid, esize);
            cdfh.extlen -= 4;
            bleft -= 4;
            if (cdfh.extlen < esize) break;
            cdfh.extlen -= esize;
            bleft -= esize;
            // skip unknown info
            if (eid != 1 || esize < /*Z64Extra.sizeof*/8) {
              fl.seek(esize, SEEK_CUR);
            } else {
              // wow, Zip64 info
              found = true;
              if (fi.size == 0xffff_ffffu) {
                if (fl.rawRead((&fi.size)[0..1]).length != 1) throw new NamedException!"ZipArchive"("reading error");
                esize -= 8;
                //debug writeln(" size=", fi.size);
              }
              if (fi.pksize == 0xffff_ffffu) {
                if (esize == 0) {
                  //fi.pksize = ulong.max; // this means "get from local header"
                  // read local file header; it's slow, but i don't care
                  /*
                  if (fi.hdrofs == 0xffff_ffffu) throw new NamedException!"ZipArchive"("invalid zip64 archive (3)");
                  CDFileHeader lfh = void;
                  auto oldpos = fl.tell;
                  fl.seek(fi.hdrofs);
                  if (fl.rawRead((&lfh)[0..1]).length != 1) throw new NamedException!"ZipArchive"("reading error");
                  assert(0);
                  */
                  throw new NamedException!"ZipArchive"("invalid zip64 archive (4)");
                } else {
                  if (esize < 8) throw new NamedException!"ZipArchive"("invalid zip64 archive (1)");
                  if (fl.rawRead((&fi.pksize)[0..1]).length != 1) throw new NamedException!"ZipArchive"("reading error");
                  esize -= 8;
                }
              }
              if (fi.hdrofs == 0xffff_ffffu) {
                if (esize < 8) throw new NamedException!"ZipArchive"("invalid zip64 archive (2)");
                if (fl.rawRead((&fi.hdrofs)[0..1]).length != 1) throw new NamedException!"ZipArchive"("reading error");
                esize -= 8;
              }
              if (esize > 0) fl.seek(esize, SEEK_CUR); // skip possible extra data
              //if (z64e.disk != 0) throw new NamedException!"ZipArchive"("invalid central directory entry (disk number)");
              break;
            }
          }
          if (!found) {
            debug writeln("required zip64 record not found");
            //throw new NamedException!"ZipArchive"("required zip64 record not found");
            //fi.size = fi.pksize = 0x1_0000_0000Lu; // hack: skip it
            doSkip = true;
          }
        }
        if (!doSkip && nbpos > 0 && nb[nbpos-1] != '/') {
          if (auto idx = nb[0..nbpos] in knownNames) {
            // replace
            auto fip = &dir[*idx];
            fip.packed = fi.packed;
            fip.pksize = fi.pksize;
            fip.size = fi.size;
            fip.hdrofs = fi.hdrofs;
          } else {
            // add new
            if (dir.length == uint.max) throw new NamedException!"ZipArchive"("directory too long");
            if (lastSlash) {
              fi.path = cast(string)nb[0..lastSlash]; // this is safe
              fi.name = cast(string)nb[lastSlash..nbpos]; // this is safe
            } else {
              fi.path = "";
              fi.name = cast(string)nb[0..nbpos]; // this is safe
            }
            knownNames[fi.name] = cast(uint)dir.length;
            dir ~= fi;
          }
          //debug writefln("%10s %10s %s %04s/%02s/%02s %02s:%02s:%02s %s", fi.pksize, fi.size, (fi.packed ? "P" : "."), cdfh.year, cdfh.month, cdfh.day, cdfh.hour, cdfh.min, cdfh.sec, fi.name);
        }
        // skip extra and comments
        fl.seek(cdfh.extlen+cdfh.cmtlen, SEEK_CUR);
        bleft -= cdfh.namelen+cdfh.extlen+cdfh.cmtlen;
        continue;
      }
      // wtf?!
      throw new NamedException!"ZipArchive"("unknown central directory entry");
    }
    debug writeln(dir.length, " files found");
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private:
align(1) static struct ZipFileHeader {
align(1):
  char[4] sign; // "PK\x03\x04"
  ushort extrver; // version needed to extract
  ushort gflags; // general purpose bit flag
  ushort method; // compression method
  ushort mtime; // last mod file time
  ushort mdate; // last mod file date
  uint crc32;
  uint pksize; // compressed size
  uint size; // uncompressed size
  ushort namelen; // file name length
  ushort extlen; // extra field length
}

align(1) static struct CDFileHeader {
align(1):
  //char[4] sign; // "PK\x01\x02"
  ushort madebyver; // version made by
  ushort extrver; // version needed to extract
  ushort gflags; // general purpose bit flag
  ushort method; // compression method
  ushort mtime; // last mod file time
  ushort mdate; // last mod file date
  uint crc32;
  uint pksize; // compressed size
  uint size; // uncompressed size
  ushort namelen; // file name length
  ushort extlen; // extra field length
  ushort cmtlen; // file comment length
  ushort disk; // disk number start
  ushort iattr; // internal file attributes
  uint attr; // external file attributes
  uint hdrofs; // relative offset of local header

@property pure const nothrow @safe @nogc:
  ubyte hour () { return (mtime>>11); }
  ubyte min () { return (mtime>>5)&0x3f; }
  ubyte sec () { return (mtime&0x1f)*2; }

  ushort year () { return cast(ushort)((mdate>>9)+1980); }
  ubyte month () { return (mdate>>5)&0x0f; }
  ubyte day () { return (mdate&0x1f); }
}

align(1) static struct EOCDHeader {
align(1):
  char[4] sign; // "PK\x05\x06"
  ushort diskno; // number of this disk
  ushort diskcd; // number of the disk with the start of the central directory
  ushort diskfileno; // total number of entries in the central directory on this disk
  ushort fileno; // total number of entries in the central directory
  uint cdsize; // size of the central directory
  uint cdofs; // offset of start of central directory with respect to the starting disk number
  ushort cmtsize; // .ZIP file comment length
}

align(1) static struct EOCD64Header {
align(1):
  char[4] sign; // "PK\x06\x06"
  ulong eocdsize; // size of zip64 end of central directory record
  ushort madebyver; // version made by
  ushort extrver; // version needed to extract
  uint diskno; // number of this disk
  uint diskcd; // number of the disk with the start of the central directory
  ulong diskfileno; // total number of entries in the central directory
  ulong fileno; // total number of entries in the central directory
  ulong cdsize; // size of the central directory
  ulong cdofs; // offset of start of central directory with respect to the starting disk number
}

align(1) static struct Z64Locator {
align(1):
  char[4] sign; // "PK\x06\x07"
  uint diskcd; // number of the disk with the start of the zip64 end of central directory
  long ecd64ofs; // relative offset of the zip64 end of central directory record
  uint diskno; // total number of disks
}

align(1) static struct Z64Extra {
align(1):
  ulong size;
  ulong pksize;
  ulong hdrofs;
  uint disk; // number of the disk on which this file starts
}
