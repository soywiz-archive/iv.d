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
module iv.vfs.arcs.zip;

import iv.vfs : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
shared static this () {
  vfsRegisterDetector(new ZipDetector());
}


// ////////////////////////////////////////////////////////////////////////// //
private final class ZipDetector : VFSDriverDetector {
  override VFSDriver tryOpen (VFile fl) {
    debug(ziparc) { import std.stdio : writeln; writeln("trying ZIP..."); }
    try {
      auto zip = new ZipArchiveImpl(fl);
      return new VFSDriverZip(zip);
    } catch (Exception) {}
    return null;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverZip : VFSDriver {
private:
  ZipArchiveImpl zip;

public:
  this (ZipArchiveImpl azip) {
    if (azip is null) throw new VFSException("wtf?!");
    zip = azip;
  }

  /// doesn't do any security checks, 'cause i don't care
  override VFile tryOpen (const(char)[] fname) {
    static import core.stdc.stdio;
    if (fname.length == 0) return VFile.init;
    try {
      return zip.fopen(fname);
    } catch (Exception) {}
    return VFile.init;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private final class ZipArchiveImpl {
protected:
  static struct FileInfo {
    bool packed; // only "store" and "deflate" are supported
    ulong pksize;
    ulong size;
    ulong hdrofs;
    string name;
  }

  // for dir range
  public static struct DirEntry {
    string name;
    ulong size;
  }

protected:
  VFile st;
  FileInfo[] dir;
  bool mNormNames; // true: convert names to lower case, do case-insensitive comparison (ASCII only)

  VFile wrap (usize idx) {
    assert(idx < dir.length);
    // read file header
    ZipFileHeader zfh = void;
    st.seek(dir[idx].hdrofs);
    st.rawReadExact((&zfh)[0..1]);
    if (zfh.sign != "PK\x03\x04") throw new VFSException("invalid ZIP archive entry");
    zfh.fixEndian;
    // skip name and extra
    auto xpos = st.tell;
    auto stpos = xpos+zfh.namelen+zfh.extlen;
    auto size = dir[idx].size;
    auto pksize = dir[idx].pksize;
    VFSZLibMode mode = (dir[idx].packed ? VFSZLibMode.Zip : VFSZLibMode.Raw);
    return wrapZLibStreamRO(st, mode, size, stpos, pksize);
  }

public:
  this (VFile fl, bool anormNames=true) {
    mNormNames = anormNames;
    open(fl);
    st = fl;
  }

  final @property auto files () {
    static struct Range {
    private:
      ZipArchiveImpl me;
      usize curindex;

    nothrow @safe @nogc:
      this (ZipArchiveImpl ame, usize aidx=0) { me = ame; curindex = aidx; }

    public:
      @property bool empty () const { return (curindex >= me.dir.length); }
      @property DirEntry front () const {
        return DirEntry(
          (curindex < me.dir.length ? me.dir[cast(usize)curindex].name : null),
          (curindex < me.dir.length ? me.dir[cast(usize)curindex].size : 0));
      }
      @property Range save () { return Range(me, curindex); }
      void popFront () { if (curindex < me.dir.length) ++curindex; }
      @property usize length () const { return me.dir.length; }
      @property usize position () const { return curindex; } // current position
      @property void position (usize np) { curindex = np; }
      void rewind () { curindex = 0; }
    }
    return Range(this);
  }

  VFile fopen (ref in DirEntry de) {
    import iv.vfs.koi8 : koi8StrCaseEqu;
    foreach_reverse (immutable idx, ref fi; dir) {
      if (mNormNames) {
        if (koi8StrCaseEqu(fi.name, de.name)) return wrap(idx);
      } else {
        if (fi.name == de.name) return wrap(idx);
      }
    }
    throw new VFSNamedException!"ZipArchive"("file not found");
  }

  VFile fopen (const(char)[] fname) {
    DirEntry de;
    de.name = cast(string)fname; // it's safe here
    return fopen(de);
  }

private:
  void open (VFile fl) {
    debug(ziparc) import std.stdio : writeln, writefln;

    if (fl.size > 0xffff_ffffu) throw new VFSNamedException!"ZipArchive"("file too big");
    ulong flsize = fl.size;
    if (flsize < EOCDHeader.sizeof) throw new VFSNamedException!"ZipArchive"("file too small");

    // search for "end of central dir"
    auto cdbuf = xalloc!ubyte(65536+EOCDHeader.sizeof+Z64Locator.sizeof);
    scope(exit) xfree(cdbuf);
    ubyte[] buf;
    ulong ubufpos;
    if (flsize < cdbuf.length) {
      fl.seek(0);
      buf = fl.rawRead(cdbuf[0..cast(usize)flsize]);
      if (buf.length != flsize) throw new VFSNamedException!"ZipArchive"("reading error");
    } else {
      fl.seek(-cast(ulong)cdbuf.length, Seek.End);
      ubufpos = fl.tell;
      buf = fl.rawRead(cdbuf[]);
      if (buf.length != cdbuf.length) throw new VFSNamedException!"ZipArchive"("reading error");
    }
    int pos;
    for (pos = cast(int)(buf.length-EOCDHeader.sizeof); pos >= 0; --pos) {
      if (buf[pos] == 'P' && buf[pos+1] == 'K' && buf[pos+2] == 5 && buf[pos+3] == 6) break;
    }
    if (pos < 0) throw new VFSNamedException!"ZipArchive"("no central dir end marker found");
    auto eocd = *cast(EOCDHeader*)&buf[pos];
    eocd.fixEndian;
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
      if (pos < Z64Locator.sizeof) throw new VFSNamedException!"ZipArchive"("corrupted archive");
      auto lt64 = *cast(Z64Locator*)&buf[pos-Z64Locator.sizeof];
      lt64.fixEndian;
      if (lt64.sign != "PK\x06\x07") throw new VFSNamedException!"ZipArchive"("corrupted archive");
      if (lt64.diskcd != 0 || lt64.diskno > 1) throw new VFSNamedException!"ZipArchive"("multidisk archive");
      debug(ziparc) writeln("ecd64ofs=", lt64.ecd64ofs);
      if (lt64.ecd64ofs < 0 || lt64.ecd64ofs+EOCD64Header.sizeof > ubufpos+pos-Z64Locator.sizeof) throw new VFSNamedException!"ZipArchive"("corrupted archive");
      EOCD64Header e64 = void;
      fl.seek(lt64.ecd64ofs);
      if (fl.rawRead((&e64)[0..1]).length != 1) throw new VFSNamedException!"ZipArchive"("reading error");
      e64.fixEndian;
      if (e64.sign != "PK\x06\x06") throw new VFSNamedException!"ZipArchive"("corrupted archive");
      if (e64.diskno != 0 || e64.diskcd != 0) throw new VFSNamedException!"ZipArchive"("multidisk archive");
      if (e64.diskfileno != e64.fileno) throw new VFSNamedException!"ZipArchive"("corrupted archive");
      if (e64.cdsize >= lt64.ecd64ofs) throw new VFSNamedException!"ZipArchive"("corrupted archive");
      if (e64.cdofs >= lt64.ecd64ofs || e64.cdofs+e64.cdsize > lt64.ecd64ofs) throw new VFSNamedException!"ZipArchive"("corrupted archive");
      cdofs = e64.cdofs;
      cdsize = e64.cdsize;
    } else {
      if (eocd.diskno != 0 || eocd.diskcd != 0) throw new VFSNamedException!"ZipArchive"("multidisk archive");
      if (eocd.diskfileno != eocd.fileno || ubufpos+pos+EOCDHeader.sizeof+eocd.cmtsize != flsize) throw new VFSNamedException!"ZipArchive"("corrupted archive");
      cdofs = eocd.cdofs;
      cdsize = eocd.cdsize;
      if (cdofs >= ubufpos+pos || flsize-cdofs < cdsize) throw new VFSNamedException!"ZipArchive"("corrupted archive");
    }

    // now read central directory
    auto namebuf = xalloc!char(0x10000);
    scope(exit) xfree(namebuf);

    uint[string] knownNames; // value is dir index
    scope(exit) knownNames.destroy;
    auto bleft = cdsize;
    fl.seek(cdofs);
    CDFileHeader cdfh = void;
    char[4] sign;
    dir.assumeSafeAppend; // yep
    while (bleft > 0) {
      if (bleft < 4) break;
      if (fl.rawRead(sign[]).length != sign.length) throw new VFSNamedException!"ZipArchive"("reading error");
      bleft -= 4;
      if (sign[0] != 'P' || sign[1] != 'K') throw new VFSNamedException!"ZipArchive"("invalid central directory entry");
      // digital signature?
      if (sign[2] == 5 && sign[3] == 5) {
        // yes, skip it
        if (bleft < 2) throw new VFSNamedException!"ZipArchive"("reading error");
        auto sz = fl.readNum!ushort;
        if (sz > bleft) throw new VFSNamedException!"ZipArchive"("invalid central directory entry");
        fl.seek(sz, Seek.Cur);
        bleft -= sz;
        continue;
      }
      // file item?
      if (sign[2] == 1 && sign[3] == 2) {
        if (bleft < cdfh.sizeof) throw new VFSNamedException!"ZipArchive"("reading error");
        if (fl.rawRead((&cdfh)[0..1]).length != 1) throw new VFSNamedException!"ZipArchive"("reading error");
        cdfh.fixEndian;
        bleft -= cdfh.sizeof;
        if (cdfh.disk != 0) throw new VFSNamedException!"ZipArchive"("invalid central directory entry (disk number)");
        if (bleft < cdfh.namelen+cdfh.extlen+cdfh.cmtlen) throw new VFSNamedException!"ZipArchive"("invalid central directory entry");
        // skip bad files
        if ((cdfh.method != 0 && cdfh.method != 8) || cdfh.namelen == 0 || (cdfh.gflags&0b10_0000_0110_0001) != 0 || (cdfh.attr&0x58) != 0 ||
            cast(long)cdfh.hdrofs+(cdfh.method ? cdfh.pksize : cdfh.size) >= ubufpos+pos)
        {
          // ignore this
          fl.seek(cdfh.namelen+cdfh.extlen+cdfh.cmtlen, Seek.Cur);
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
        if (fl.rawRead(namebuf[0..cdfh.namelen]).length != cdfh.namelen) throw new VFSNamedException!"ZipArchive"("reading error");
        auto nb = new char[](cdfh.namelen);
        uint nbpos = 0;
        foreach (char ch; namebuf[0..cdfh.namelen]) {
          if (ch == 0) break;
          if (ch == '\\') ch = '/'; // just in case
          if (ch == '/' && (nbpos == 0 || nb.ptr[nbpos-1] == '/')) continue;
          nb.ptr[nbpos++] = ch;
        }
        bool doSkip = false;
        // should we parse extra field?
        debug(ziparc) writefln("size=0x%08x; pksize=0x%08x; packed=%s", fi.size, fi.pksize, (fi.packed ? "tan" : "ona"));
        if (zip64 && (fi.size == 0xffff_ffffu || fi.pksize == 0xffff_ffffu || fi.hdrofs == 0xffff_ffffu)) {
          // yep, do it
          bool found = false;
          //Z64Extra z64e = void;
          debug(ziparc) writeln("extlen=", cdfh.extlen);
          while (cdfh.extlen >= 4) {
            auto eid = fl.readNum!ushort;
            auto esize = fl.readNum!ushort;
            debug(ziparc) writefln("0x%04x %s", eid, esize);
            cdfh.extlen -= 4;
            bleft -= 4;
            if (cdfh.extlen < esize) break;
            cdfh.extlen -= esize;
            bleft -= esize;
            // skip unknown info
            if (eid != 1 || esize < /*Z64Extra.sizeof*/8) {
              fl.seek(esize, Seek.Cur);
            } else {
              // wow, Zip64 info
              found = true;
              if (fi.size == 0xffff_ffffu) {
                if (fl.rawRead((&fi.size)[0..1]).length != 1) throw new VFSNamedException!"ZipArchive"("reading error");
                version(BigEndian) { import std.bitmanip : swapEndian; fi.size = swapEndian(fi.size); }
                esize -= 8;
                //debug(ziparc) writeln(" size=", fi.size);
              }
              if (fi.pksize == 0xffff_ffffu) {
                if (esize == 0) {
                  //fi.pksize = ulong.max; // this means "get from local header"
                  // read local file header; it's slow, but i don't care
                  /*
                  if (fi.hdrofs == 0xffff_ffffu) throw new VFSNamedException!"ZipArchive"("invalid zip64 archive (3)");
                  CDFileHeader lfh = void;
                  auto oldpos = fl.tell;
                  fl.seek(fi.hdrofs);
                  if (fl.rawRead((&lfh)[0..1]).length != 1) throw new VFSNamedException!"ZipArchive"("reading error");
                  assert(0);
                  */
                  throw new VFSNamedException!"ZipArchive"("invalid zip64 archive (4)");
                } else {
                  if (esize < 8) throw new VFSNamedException!"ZipArchive"("invalid zip64 archive (1)");
                  if (fl.rawRead((&fi.pksize)[0..1]).length != 1) throw new VFSNamedException!"ZipArchive"("reading error");
                  version(BigEndian) { import std.bitmanip : swapEndian; fi.pksize = swapEndian(fi.pksize); }
                  esize -= 8;
                }
              }
              if (fi.hdrofs == 0xffff_ffffu) {
                if (esize < 8) throw new VFSNamedException!"ZipArchive"("invalid zip64 archive (2)");
                if (fl.rawRead((&fi.hdrofs)[0..1]).length != 1) throw new VFSNamedException!"ZipArchive"("reading error");
                version(BigEndian) { import std.bitmanip : swapEndian; fi.hdrofs = swapEndian(fi.hdrofs); }
                esize -= 8;
              }
              if (esize > 0) fl.seek(esize, Seek.Cur); // skip possible extra data
              //if (z64e.disk != 0) throw new VFSNamedException!"ZipArchive"("invalid central directory entry (disk number)");
              break;
            }
          }
          if (!found) {
            debug(ziparc) writeln("required zip64 record not found");
            //throw new VFSNamedException!"ZipArchive"("required zip64 record not found");
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
            if (dir.length == uint.max) throw new VFSNamedException!"ZipArchive"("directory too long");
            fi.name = cast(string)nb[0..nbpos]; // this is safe
            knownNames[fi.name] = cast(uint)dir.length;
            dir ~= fi;
          }
          //debug(ziparc) writefln("%10s %10s %s %04s/%02s/%02s %02s:%02s:%02s %s", fi.pksize, fi.size, (fi.packed ? "P" : "."), cdfh.year, cdfh.month, cdfh.day, cdfh.hour, cdfh.min, cdfh.sec, fi.name);
        }
        // skip extra and comments
        fl.seek(cdfh.extlen+cdfh.cmtlen, Seek.Cur);
        bleft -= cdfh.namelen+cdfh.extlen+cdfh.cmtlen;
        continue;
      }
      // wtf?!
      throw new VFSNamedException!"ZipArchive"("unknown central directory entry");
    }
    debug(ziparc) writeln(dir.length, " files found");
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

  void fixEndian () nothrow @trusted @nogc {
    version(BigEndian) {
      import std.bitmanip : swapEndian;
      extrver = swapEndian(extrver);
      gflags = swapEndian(gflags);
      method = swapEndian(method);
      mtime = swapEndian(mtime);
      mdate = swapEndian(mdate);
      crc32 = swapEndian(crc32);
      pksize = swapEndian(pksize);
      size = swapEndian(size);
      namelen = swapEndian(namelen);
      extlen = swapEndian(extlen);
    }
  }
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

  void fixEndian () nothrow @trusted @nogc {
    version(BigEndian) {
      import std.bitmanip : swapEndian;
      madebyver = swapEndian(madebyver);
      extrver = swapEndian(extrver);
      gflags = swapEndian(gflags);
      method = swapEndian(method);
      mtime = swapEndian(mtime);
      mdate = swapEndian(mdate);
      crc32 = swapEndian(crc32);
      pksize = swapEndian(pksize);
      size = swapEndian(size);
      namelen = swapEndian(namelen);
      extlen = swapEndian(extlen);
      cmtlen = swapEndian(cmtlen);
      disk = swapEndian(disk);
      iattr = swapEndian(iattr);
      hdrofs = swapEndian(hdrofs);
    }
  }
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

  void fixEndian () nothrow @trusted @nogc {
    version(BigEndian) {
      import std.bitmanip : swapEndian;
      diskno = swapEndian(diskno);
      fileno = swapEndian(fileno);
      cdsize = swapEndian(cdsize);
      cdofs = swapEndian(cdofs);
      cmtsize = swapEndian(cmtsize);
    }
  }
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

  void fixEndian () nothrow @trusted @nogc {
    version(BigEndian) {
      import std.bitmanip : swapEndian;
      eocdsize = swapEndian(eocdsize);
      madebyver = swapEndian(madebyver);
      extrver = swapEndian(extrver);
      diskno = swapEndian(diskno);
      diskcd = swapEndian(diskcd);
      diskfileno = swapEndian(diskfileno);
      fileno = swapEndian(fileno);
      cdsize = swapEndian(cdsize);
      cdofs = swapEndian(cdofs);
    }
  }
}

align(1) static struct Z64Locator {
align(1):
  char[4] sign; // "PK\x06\x07"
  uint diskcd; // number of the disk with the start of the zip64 end of central directory
  long ecd64ofs; // relative offset of the zip64 end of central directory record
  uint diskno; // total number of disks

  void fixEndian () nothrow @trusted @nogc {
    version(BigEndian) {
      import std.bitmanip : swapEndian;
      diskcd = swapEndian(diskcd);
      ecd64ofs = swapEndian(ecd64ofs);
      diskno = swapEndian(diskno);
    }
  }
}

align(1) static struct Z64Extra {
align(1):
  ulong size;
  ulong pksize;
  ulong hdrofs;
  uint disk; // number of the disk on which this file starts

  void fixEndian () nothrow @trusted @nogc {
    version(BigEndian) {
      import std.bitmanip : swapEndian;
      size = swapEndian(size);
      pksize = swapEndian(pksize);
      disk = swapEndian(disk);
    }
  }
}
