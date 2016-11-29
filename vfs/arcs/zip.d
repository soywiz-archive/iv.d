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

import iv.vfs.types : usize, ssize, Seek;
import iv.vfs.augs;
import iv.vfs.main;
import iv.vfs.vfile;


// ////////////////////////////////////////////////////////////////////////// //
private import iv.vfs.arcs.internal : VFSSimpleArchiveDetectorMixin;
mixin(VFSSimpleArchiveDetectorMixin!"Zip");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverZip : VFSDriver {
  private import iv.vfs.arcs.internal : VFSSimpleArchiveDriverMixin;
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    bool packed; // only "store" and "deflate" are supported
    long pksize;
    long size;
    long hdrofs;
    string name;
  }

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
    if (zfh.method == 6) {
      return wrapStream(ExplodeLowLevelRO(st, zfh.gflags, size, stpos, pksize, dir[idx].name), dir[idx].name);
    } else {
      VFSZLibMode mode = (dir[idx].packed ? VFSZLibMode.Zip : VFSZLibMode.Raw);
      return wrapZLibStreamRO(st, mode, size, stpos, pksize, dir[idx].name);
    }
  }

  void open (VFile fl, const(char)[] prefixpath) {
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
      //debug(ziparc) writefln("flsize: 0x%08x  expected: 0x%08x", cast(uint)flsize, cast(uint)(ubufpos+pos+EOCDHeader.sizeof+eocd.cmtsize));
      if (eocd.diskfileno != eocd.fileno) throw new VFSNamedException!"ZipArchive"("corrupted archive");
      // relax it a little
      if (ubufpos+pos+EOCDHeader.sizeof+eocd.cmtsize > flsize) throw new VFSNamedException!"ZipArchive"("corrupted archive");
      cdofs = eocd.cdofs;
      cdsize = eocd.cdsize;
      if (cdofs >= ubufpos+pos || flsize-cdofs < cdsize) throw new VFSNamedException!"ZipArchive"("corrupted archive");
    }

    // now read central directory
    auto namebuf = xalloc!char(0x10000);
    scope(exit) xfree(namebuf);

    auto bleft = cdsize;
    fl.seek(cdofs);
    CDFileHeader cdfh = void;
    char[4] sign;
    dir.assumeSafeAppend; // yep
    while (bleft > 0) {
      debug(ziparc) writefln("pos: 0x%08x (%s bytes left)", cast(uint)fl.tell, bleft);
      if (bleft < 4) break;
      if (fl.rawRead(sign[]).length != sign.length) throw new VFSNamedException!"ZipArchive"("reading error");
      bleft -= 4;
      if (sign[0] != 'P' || sign[1] != 'K') {
        debug(ziparc) writeln("SIGN: NOT PK!");
        throw new VFSNamedException!"ZipArchive"("invalid central directory entry");
      }
      debug(ziparc) writefln("SIGN: 0x%02x 0x%02x", cast(ubyte)sign[2], cast(ubyte)sign[3]);
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
        if (cdfh.method != 0 && cdfh.method != 8 && cdfh.method != 6) {
          debug(ziparc) writeln("  INVALID: method=", cdfh.method);
          throw new VFSNamedException!"ZipArchive"("invalid method");
        }
        if (cdfh.namelen == 0 || (cdfh.gflags&0b10_0000_0110_0001) != 0 || (cdfh.attr&0x58) != 0 ||
            cast(long)cdfh.hdrofs+(cdfh.method ? cdfh.pksize : cdfh.size) >= ubufpos+pos)
        {
          debug(ziparc) writeln("  ignored: method=", cdfh.method);
          // ignore this
          fl.seek(cdfh.namelen+cdfh.extlen+cdfh.cmtlen, Seek.Cur);
          bleft -= cdfh.namelen+cdfh.extlen+cdfh.cmtlen;
          continue;
        }
        FileInfo fi;
        //fi.gflags = cdfh.gflags;
        fi.packed = (cdfh.method != 0);
        fi.pksize = cdfh.pksize;
        fi.size = cdfh.size;
        fi.hdrofs = cdfh.hdrofs;
        if (!fi.packed) fi.pksize = fi.size;
        // now, this is valid file, so read it's name
        if (fl.rawRead(namebuf[0..cdfh.namelen]).length != cdfh.namelen) throw new VFSNamedException!"ZipArchive"("reading error");
        auto nb = new char[](prefixpath.length+cdfh.namelen);
        usize nbpos = prefixpath.length;
        if (nbpos) nb[0..nbpos] = prefixpath[];
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
          // add new
          if (dir.length == uint.max) throw new VFSNamedException!"ZipArchive"("directory too long");
          fi.name = cast(string)nb[0..nbpos]; // this is safe
          dir ~= fi;
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


// ////////////////////////////////////////////////////////////////////////// //
// slow and stupid "implode" unpacker
struct Exploder {
  static struct HufNode {
    ushort b0; // 0-branch value + leaf node flag
    ushort b1; // 1-branch value + leaf node flag
    HufNode* jump; // 1-branch jump address
  }

  enum LITERALS = 288;

  HufNode[LITERALS] literalTree;
  HufNode[32] distanceTree;
  HufNode* Places = null;

  HufNode[64] impDistanceTree;
  HufNode[64] impLengthTree;
  ubyte len = 0;
  short[17] fpos = 0;
  int* flens;
  short fmax;

  int[256] ll;

  int minMatchLen = 3;
  ushort gflags;

  VFile zfl;
  long zflpos;
  long zflorg;
  long zflsize;
  long zflleft;
  uint upkleft;
  uint upktotalsize;
  ubyte[32768] inbuf;
  uint ibpos, ibused;
  ubyte bb = 1; // getbit mask
  bool ateof;

  ubyte[32768] buf32k;
  uint bIdx;

  ubyte[512] upkbuf; // way too much
  uint upkbufused, upkbufpos;

  //this () {}

//final:
  void setup (VFile fl, ushort agflags, long apos, uint apksize, uint aupksize) {
    zfl = fl;
    bb = 1;
    ibpos = ibused = 0;
    ateof = false;
    zflpos = zflorg = apos;
    zflsize = apksize;
    gflags = agflags;
    upktotalsize = aupksize;
    reset();
  }

  void reset () {
    bb = 1;
    ibpos = ibused = 0;
    ateof = false;
    zflpos = zflorg;
    zflleft = zflsize;
    buf32k[] = 0;
    bIdx = 0;
    upkleft = upktotalsize;
    upkbufused = 0;
    if (upktotalsize == 0) return;
    if ((gflags&4) != 0) {
      // 3 trees: literals, lenths, distance top 6
      minMatchLen = 3;
      createTree(literalTree.ptr, decodeSF(ll.ptr), ll.ptr);
    } else {
      // 2 trees: lenths, distance top 6
      minMatchLen = 2;
    }
    createTree(impLengthTree.ptr, decodeSF(ll.ptr), ll.ptr);
    createTree(impDistanceTree.ptr, decodeSF(ll.ptr), ll.ptr);
  }

  // has more bytes to unpack?
  @property bool hasBytes () const pure nothrow @safe @nogc { pragma(inline, true); return (upkbufpos < upkbufused || upkleft != 0); }

  // get next unpacked byte
  ubyte getByte () {
    if (upkbufpos < upkbufused) return upkbuf.ptr[upkbufpos++];
    upkbufpos = upkbufused = 0;
    if (upkleft == 0) return 0; // just in case
    implodeStep();
    if (upkbufpos >= upkbufused) throw new Exception("wtf?!");
    return upkbuf.ptr[upkbufpos++];
  }

private:
  T readPackedByte(T=int) () if (is(T == int) || is(T == ubyte)) {
    if (ateof) {
      static if (is(T == int)) return -1; else throw new Exception("unexpected EOF");
    }
    if (ibpos >= ibused) {
      ibpos = ibused = 0;
      auto rd = cast(uint)(zflleft > inbuf.length ? inbuf.length : zflleft);
      if (rd == 0) { ateof = true; return readPackedByte!T(); }
      zfl.seek(zflpos);
      zfl.rawReadExact(inbuf[0..rd]);
      ibused = rd;
      zflpos += rd;
      zflleft -= rd;
      //{ import core.stdc.stdio; printf("XPL: read %u bytes\n", rd); }
    }
    return inbuf.ptr[ibpos++];
  }

  ubyte readPackedBit () {
    ubyte res = (bb&1);
    bb >>= 1;
    if (bb == 0) {
      bb = readPackedByte!ubyte();
      res = bb&1;
      bb = (bb>>1)|0x80;
    }
    return res;
  }

  ubyte readPackedBits (ubyte count) {
    ubyte res = 0, mask = 1;
    if (count > 8) assert(0, "wtf?!");
    while (count--) {
      if (readPackedBit()) res |= mask;
      mask <<= 1;
    }
    return res;
  }

  void bufferUpkByte (ubyte a) {
    //CRC = updcrc(cast(ubyte)a, CRC);
    buf32k[bIdx++] = a;
    bIdx &= 0x7fff;
    if (upkleft) {
      if (upkbufused >= upkbuf.length) assert(0, "wtf?!");
      upkbuf.ptr[upkbufused++] = a;
      --upkleft;
    }
  }

  int decodeSFValue (HufNode *currentTree) {
    HufNode* x = currentTree;
    // decode one symbol of the data
    for (;;) {
      if (!readPackedBit()) {
        // only the decision is reversed!
        if ((x.b1&0x8000) == 0) return x.b1; // If leaf node, return data
        x = x.jump;
      } else {
        if ((x.b0&0x8000) == 0) return x.b0; // If leaf node, return data
        ++x;
      }
    }
    return -1;
  }

  int decodeSF (int* table) {
    int v = 0;
    immutable n = readPackedByte()+1;
    foreach (immutable i; 0..n) {
      auto a = readPackedByte();
      auto nv = ((a >> 4)&15)+1;
      auto bl = (a & 15)+1;
      while (nv--) table[v++] = bl;
    }
    return v; // entries used
  }

  /*
    Note:
        The tree create and distance code trees <= 32 entries
        and could be represented with the shorter tree algorithm.
        I.e. use a X/Y-indexed table for each struct member.
  */
  void createTree (HufNode* currentTree, int numval, int* lengths) {
    // create the Huffman decode tree/table
    Places = currentTree;
    flens = lengths;
    fmax  = cast(short)numval;
    fpos[0..17] = 0;
    len = 0;

    /*
     * A recursive routine which creates the Huffman decode tables
     *
     * No presorting of code lengths are needed, because a counting sort is perfomed on the fly.
     *
     * Maximum recursion depth is equal to the maximum Huffman code length, which is 15 in the deflate algorithm.
     * (16 in Inflate!) */
    void rec () {
      int isPat () {
        for (;;) {
          if (fpos[len] >= fmax) return -1;
          if (flens[fpos[len]] == len) return fpos[len]++;
          ++fpos[len];
        }
      }

      HufNode* curplace = Places;
      int tmp;

      if (len == 17) throw new Exception("invalid huffman tree");
      ++Places;
      ++len;

      tmp = isPat();
      if (tmp >= 0) {
        curplace.b0 = cast(ushort)tmp; // leaf cell for 0-bit
      } else {
        // not a Leaf cell
        curplace.b0 = 0x8000;
        rec();
      }
      tmp = isPat();
      if (tmp >= 0) {
        curplace.b1 = cast(ushort)tmp; // leaf cell for 1-bit
        curplace.jump = null; // Just for the display routine
      } else {
        // Not a Leaf cell
        curplace.b1 = 0x8000;
        curplace.jump = Places;
        rec();
      }
      --len;
    }

    rec();
  }

  /* Note: Imploding could use the lighter huffman tree routines, as the
         max number of entries is 256. But too much code would need to
         be duplicated.
   * gflags: CDFileHeader.gflags
   */
  void implodeStep () {
    //CRC = 0xffffffff;
    if (upkleft == 0) return;
    int c = readPackedBits(1);
    if (c) {
      // literal data
      if ((gflags&4) != 0) {
        c = decodeSFValue(literalTree.ptr);
      } else {
        c = readPackedBits(8);
      }
      bufferUpkByte(cast(ubyte)c);
    } else {
      int dist;
      if ((gflags&2) != 0) {
        // 8k dictionary
        dist = readPackedBits(7);
        c = decodeSFValue(impDistanceTree.ptr);
        dist |= (c<<7);
      } else {
        // 4k dictionary
        dist = readPackedBits(6);
        c = decodeSFValue(impDistanceTree.ptr);
        dist |= (c<<6);
      }
      int len = decodeSFValue(impLengthTree.ptr);
      if (len == 63) len += readPackedBits(8);
      len += minMatchLen;
      ++dist;
      foreach (immutable i; 0..len) bufferUpkByte(buf32k.ptr[(bIdx-dist)&0x7fff]);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct ExplodeLowLevelRO {
  Exploder epl;
  long size; // unpacked size
  long pos; // current file position
  long prpos; // previous file position
  bool eofhit;
  string fname;

  this (VFile fl, ushort agflags, long aupsize, long astpos, long asize, string aname) {
    if (aupsize > uint.max) aupsize = uint.max;
    if (asize > uint.max) asize = uint.max;
    epl.setup(fl, agflags, astpos, cast(uint)asize, cast(uint)aupsize);
    eofhit = (aupsize == 0);
    size = aupsize;
    fname = aname;
  }

  @property const(char)[] name () { pragma(inline, true); return (fname !is null ? fname : epl.zfl.name); }
  @property bool isOpen () { pragma(inline, true); return epl.zfl.isOpen; }
  @property bool eof () { pragma(inline, true); return eofhit; }

  void close () {
    eofhit = true;
    if (epl.zfl.isOpen) epl.zfl.close();
  }

  ssize read (void* buf, usize count) {
    if (buf is null) return -1;
    if (count == 0 || size == 0) return 0;
    if (!isOpen) return -1; // read error
    if (size >= 0 && pos >= size) { eofhit = true; return 0; } // EOF
    // do we want to seek backward?
    if (prpos > pos) {
      // yes, rewind
      epl.reset();
      eofhit = (size == 0);
      prpos = 0;
    }
    // do we need to seek forward?
    if (prpos < pos) {
      // yes, skip data
      foreach (immutable _; 0..pos-prpos) epl.getByte();
      prpos = pos;
    }
    // unpack data
    if (size >= 0 && size-pos < count) { eofhit = true; count = cast(usize)(size-pos); }
    ubyte* dst = cast(ubyte*)buf;
    foreach (immutable _; 0..count) {
      *dst++ = epl.getByte();
      prpos = ++pos;
    }
    return count;
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
    if (ofs >= size) { eofhit = true; ofs = size; } else eofhit = false;
    pos = ofs;
    return pos;
  }
}
