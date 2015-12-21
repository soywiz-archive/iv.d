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
module iv.ziparc /*is aliced*/;


// ////////////////////////////////////////////////////////////////////////// //
final class ZipArchive {
public:
  import std.stdio : File;

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

private:
  File zfl;
  FileInfo[] dir;
  bool mNormNames; // true: convert names to lower case, do case-insensitive comparison (ASCII only)

public:
  this (string fname, bool normNames=true) {
    import std.stdio : File;
    mNormNames = normNames;
    initLock();
    zfl = File(fname);
    open(zfl);
    scope(failure) { zfl.close; zfl = zfl.init; }
  }

  // it now owns the file (if no exception was thrown)
  this (File fl, bool normNames=true) {
    mNormNames = normNames;
    initLock();
    open(fl);
    scope(success) zfl = fl;
  }

  @property auto files () {
    static struct Range {
    private:
      ZipArchive me;
      ulong curindex;

    nothrow @safe @nogc:
      this (ZipArchive ame, ulong aidx=0) { me = ame; curindex = aidx; }

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

  File fopen (ref in DirEntry de) {
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
        if (strequ(fi.path, de.path) && strequ(fi.name, de.name)) return openDirEntry(idx, fi.name);
      } else {
        if (fi.path == de.path && fi.name == de.name) return openDirEntry(idx, fi.name);
      }
    }

    throw new NamedException!"ZipArchive"("file not found");
  }

  File fopen (const(char)[] fname) {
    DirEntry de;
    auto pos = fname.length;
    while (pos > 0 && fname[pos-1] != '/') --pos;
    if (pos) {
      de.path = cast(string)fname[0..pos+1]; // it's safe here
      de.name = cast(string)fname[pos+1..$]; // it's safe here
    } else {
      de.name = cast(string)fname; // it's safe here
    }
    return fopen(de);
  }

private:
  void cleanup () {
    dir.length = 0;
  }

  void open (File fl) {
    import core.stdc.stdio : SEEK_CUR, SEEK_END;
    debug import std.stdio : writeln, writefln;
    scope(failure) cleanup();

    ushort readU16 () {
      ubyte[2] data;
      if (fl.rawRead(data[]).length != data.length) throw new NamedException!"ZipArchive"("reading error");
      return cast(ushort)(data[0]+0x100*data[1]);
    }

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
    debug {
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
        auto sz = readU16();
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
            auto eid = readU16();
            auto esize = readU16();
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


  // ////////////////////////////////////////////////////////////////////// //
  static import core.sync.mutex;

  core.sync.mutex.Mutex lock;

  void initLock () {
    lock = new core.sync.mutex.Mutex;
  }

  auto openDirEntry (uint idx, string filename) {
    import core.sys.linux.stdio : fopencookie;
    import core.stdc.stdio : FILE;
    import core.stdc.stdio : fopen, fclose;
    import core.stdc.stdlib : calloc, free;
    import etc.c.zlib;
    import std.internal.cstring : tempCString;
    import core.memory : GC;

    if (!zfl.isOpen) throw new NamedException!"ZipArchive"("archive wasn't opened");
    if (zfl.name.length == 0) throw new NamedException!"ZipArchive"("archive has no name");
    if (idx >= dir.length) if (!zfl.isOpen) throw new NamedException!"ZipArchive"("invalid dir index");
    ulong stofs;
    {
      lock.lock();
      scope(exit) lock.unlock();
      // read file header
      ZipFileHeader zfh = void;
      zfl.seek(dir[idx].hdrofs);
      if (zfl.rawRead((&zfh)[0..1]).length != 1) throw new NamedException!"ZipArchive"("reading error");
      if (zfh.sign != "PK\x03\x04") throw new NamedException!"ZipArchive"("invalid archive entry");
      // skip name and extra
      stofs = zfl.tell+zfh.namelen+zfh.extlen;
    }

    // create cookied `FILE*`
    auto fc = cast(InnerFileCookied*)calloc(1, InnerFileCookied.sizeof);
    scope(exit) if (fc !is null) free(fc);
    if (fc is null) {
      import core.exception : onOutOfMemoryErrorNoGC;
      onOutOfMemoryErrorNoGC();
    }
    (*fc) = InnerFileCookied.init;
    (*fc).stpos = stofs;
    (*fc).size = cast(uint)dir[idx].size; //FIXME
    (*fc).pksize = cast(uint)dir[idx].pksize; //FIXME
    (*fc).mode = (dir[idx].packed ? InnerFileCookied.Mode.Zip : InnerFileCookied.Mode.Raw);
    (*fc).lock = lock;
    GC.addRange(fc, InnerFileCookied.sizeof);
    // open DAT file
    //(*fc).fl = //fopen(zfl.name.tempCString!char(), "r");
    //if ((*fc).fl is null) throw new NamedException!"ZipArchive"("can't open archive file");
    (*fc).xfl = zfl;
    // open `cooked` file
    FILE* fres = fopencookie(cast(void*)fc, "r", fcdatpkCallbacks);
    if (fres is null) {
      // alas
      if ((*fc).fl !is null) fclose((*fc).fl);
      try { (*fc).xfl.detach(); } catch (Exception) {}
      throw new NamedException!"ZipArchive"("can't open cookied file");
    }
    // ok
    (*fc).initialize();
    fc = null;
    return File(fres, filename);
  }


  // ////////////////////////////////////////////////////////////////////// //
  // "inner" file processor; processes both packed and unpacked files
  // can be used as normal disk file processor too
  static struct InnerFileCookied {
    private import etc.c.zlib;
    private import core.sys.posix.sys.types : ssize_t, off64_t = off_t;
    private import core.stdc.stdio : FILE;

    enum ibsize = 32768;

    enum Mode { Raw, ZLib, Zip }

    core.sync.mutex.Mutex lock;
    // note that either one of `fl` or `xfl` must be opened and operational
    FILE* fl; // disk file, can be `null`
    File xfl; // disk file, can be closed
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

    @disable this (this);

  nothrow:
    ~this () { close(); }

    @property bool isOpen () @safe /*@nogc*/ { return (fl !is null || xfl.isOpen); }

    void initialize () {
      /*
      import core.memory : GC;
      lock = new core.sync.mutex.Mutex;
      GC.addRoot(*cast(void**)&lock);
      */
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
        try { xfl.detach(); } catch (Exception) {} // it's safe to detach closed File
      }
      eoz = true;
      /*
      if (lock !is null) {
        GC.removeRoot(*cast(void**)&lock);
        delete lock;
        lock = null;
      }
      */
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
      } else {
        // std.stdio.File
        try {
          xfl.seek(stpos+pkpos, 0);
          auto rd = xfl.rawRead(pkb[0..zs.avail_in]);
          if (rd.length != zs.avail_in) return false;
        } catch (Exception) { return false; } //BAD DOGGY!
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


    ssize_t read (void* buf, size_t count) {
      if (buf is null) return -1;
      if (count == 0 || size == 0) return 0;
      lock.lock();
      scope(exit) lock.unlock();
      if (!isOpen) return -1; // read error
      if (pos >= size) return 0; // EOF
      if (mode == Mode.Raw) {
        import core.stdc.stdio : ferror, fread;
        import core.sys.posix.stdio : fseeko;
        if (size-pos < count) count = cast(size_t)(size-pos);
        if (fl !is null) {
          // `FILE*`
          if (fseeko(fl, stpos+pos, 0) < 0) return -1;
          auto rd = fread(buf, 1, count, fl);
          if (rd != count && (rd < 0 || ferror(fl))) rd = -1;
          if (rd > 0) pos += rd;
          return rd;
        } else {
          // std.stdio.File
          try {
            xfl.seek(stpos+pos, 0);
            auto rd = xfl.rawRead(buf[0..count]);
            pos += rd.length;
            return  (rd.length == count ? rd.length : -1);
          } catch (Exception) {} //BAD DOGGY!
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
          ubyte[1024] tbuf;
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
        if (size-pos < count) count = cast(size_t)(size-pos);
        zs.next_out = cast(typeof(zs.next_out))buf;
        zs.avail_out = cast(uint)count;
        if (!unpackNextChunk()) return -1;
        prpos = (pos += count);
        return count;
      }
    }

    long seek (long ofs, int whence) {
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


static:
  //import iv.writer;
  // ////////////////////////////////////////////////////////////////////// //
  extern(C) nothrow {
    import core.sys.linux.stdio : cookie_io_functions_t;
    import core.sys.posix.sys.types : ssize_t, off64_t = off_t;

    ssize_t fcdatpkRead (void* cookie, char* buf, size_t count) {
      //{ import iv.writer; writeln("reading ", count, " bytes"); }
      import core.stdc.errno;
      auto fc = cast(InnerFileCookied*)cookie;
      auto res = fc.read(buf, count);
      if (res < 0) { errno = EIO; return -1; }
      return res;
    }

    ssize_t fcdatpkWrite (void* cookie, const(char)* buf, size_t count) {
      //{ import iv.writer; writeln("writing ", count, " bytes"); }
      import core.stdc.errno;
      errno = EIO; //FIXME: find better code
      return 0; // error; write should not return `-1`
    }

    int fcdatpkSeek (void* cookie, off64_t* offset, int whence) {
      //{ import iv.writer; writeln("seeking ", *offset, " bytes, whence=", whence); }
      import core.stdc.errno;
      auto fc = cast(InnerFileCookied*)cookie;
      auto res = fc.seek(*offset, whence);
      if (res < 0) { errno = EIO; return -1; }
      *offset = cast(off64_t)res;
      return 0;
    }

    int fcdatpkClose (void* cookie) {
      import core.memory : GC;
      import core.stdc.stdlib : free;
      //{ import iv.writer; writeln("closing"); }
      auto fc = cast(InnerFileCookied*)cookie;
      //fc.close();
      GC.removeRange(cookie);
      try { fc.__dtor(); } catch (Exception) {}
      // no need to run finalizers, we SHOULD NOT have any
      //try { GC.runFinalizers(cookie[0..InnerFileCookied.sizeof]); } catch (Exception) {}
      //fc.xfl.__dtor();
      free(cookie);
      //{ import iv.writer; writeln("closed"); }
      return 0;
    }
  }

  __gshared cookie_io_functions_t fcdatpkCallbacks = cookie_io_functions_t(
    /*.read =*/ &fcdatpkRead,
    /*.write =*/ &fcdatpkWrite,
    /*.seek =*/ &fcdatpkSeek,
    /*.close =*/ &fcdatpkClose,
  );

static:
  T[] xalloc(T) (size_t len) {
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
