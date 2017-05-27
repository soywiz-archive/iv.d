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
module iv.vfs.arc.zip /*is aliced*/;

import iv.alice;
import iv.vfs.types : Seek, VFSHiddenPointerHelper;
import iv.vfs.error;
import iv.vfs.main;
import iv.vfs.util;
import iv.vfs.vfile;
import iv.vfs.arc.internal;

//version = ziparc_debug;


// ////////////////////////////////////////////////////////////////////////// //
mixin(VFSSimpleArchiveDetectorMixin!"Zip");


// ////////////////////////////////////////////////////////////////////////// //
public final class VFSDriverZip : VFSDriver {
  mixin VFSSimpleArchiveDriverMixin;

private:
  static struct FileInfo {
    long pksize;
    long size;
    long hdrofs;
    uint modtime;
    string name;
    uint crc32;
    ushort method; // packing method
  }

  /** query various file properties; driver-specific.
   * properties of interest:
   *   "modtime" -- modify time; unixtime, UTC
   *   "packed"  -- is file packed?
   *   "pksize"  -- packed file size (for archives)
   *   "crc32"   -- crc32 value for some archives
   *   "size"    -- file size (so we can get size without opening the file)
   *   "method"  -- uint with packing method
   *   "methodname" -- string name of packing method
   */
  public override VFSVariant stat (usize idx, const(char)[] propname) {
    if (idx >= dir.length) return VFSVariant();
    if (propname == "arcname") return VFSVariant("zip");
    if (propname == "modtime") return VFSVariant(dir[idx].modtime);
    if (propname == "packed") return VFSVariant(false);
    if (propname == "pksize") return VFSVariant(dir[idx].pksize);
    if (propname == "crc32") return VFSVariant(dir[idx].crc32);
    if (propname == "size") return VFSVariant(dir[idx].size);
    if (propname == "method") return VFSVariant(cast(uint)dir[idx].method);
    if (propname == "methodname") {
      switch (dir[idx].method) {
        case 8: return VFSVariant("deflate");
        case 0: return VFSVariant("store");
        case 6: return VFSVariant("implode");
        case 1: return VFSVariant("shrink");
        case 2: case 3: case 4: case 5: return VFSVariant("reduce");
        case 9: return VFSVariant("deflate64");
        case 14: return VFSVariant("lzma");
        default: break;
      }
      return VFSVariant("unknown");
    }
    return VFSVariant();
  }

  VFile wrap (usize idx) {
    assert(idx < dir.length);
    version(ziparc_debug) debug(ziparc) import std.stdio : writeln, writefln;
    version(ziparc_debug) debug(ziparc) writeln("zip: open file #", idx, ": [", dir[idx].name, "]");
    // read file header
    ZipFileHeader zfh = void;
    st.seek(dir[idx].hdrofs);
    st.rawReadExact((&zfh)[0..1]);
    if (zfh.sign != "PK\x03\x04") {
      version(ziparc_debug) debug(ziparc) writeln("  invalid ZIP archive entry");
      throw new VFSException("invalid ZIP archive entry");
    }
    zfh.fixEndian;
    if ((zfh.gflags&0b1000) == 0) {
      if (zfh.crc32 != 0 && zfh.crc32 != dir[idx].crc32) {
        version(ziparc_debug) debug(ziparc) writefln("  invalid ZIP archive entry (crc): cdir: 0x%08x  local: 0x%08x", dir[idx].crc32, zfh.crc32);
        throw new VFSException("invalid ZIP archive entry (crc)");
      }
    }
    // skip name and extra
    auto xpos = st.tell;
    auto stpos = xpos+zfh.namelen+zfh.extlen;
    auto size = dir[idx].size;
    auto pksize = dir[idx].pksize;
    switch (zfh.method) {
      case 8: // deflate
        return wrapZLibStreamRO(st, VFSZLibMode.Zip, size, stpos, pksize, dir[idx].name);
      case 0: // store
        return wrapZLibStreamRO(st, VFSZLibMode.Raw, size, stpos, pksize, dir[idx].name);
      case 6: // implode
        return wrapStream(VStreamDecoderLowLevelRO!Exploder(st, zfh.gflags, size, stpos, pksize), dir[idx].name);
      case 1: // shrink
        return wrapStream(VStreamDecoderLowLevelRO!Deshrinker(st, zfh.gflags, size, stpos, pksize), dir[idx].name);
      case 2: case 3: case 4: case 5: // reduce
        return wrapStream(VStreamDecoderLowLevelRO!Inductor(st, zfh.method, size, stpos, pksize), dir[idx].name);
      case 9: // deflate64
        version(ziparc_debug) debug(ziparc) { import core.stdc.stdio : printf; printf("I64!\n"); }
        return wrapStream(VStreamDecoderLowLevelRO!Inflater64(st, zfh.method, size, stpos, pksize), dir[idx].name);
      case 14: // lzma
        return wrapStream(VStreamDecoderLowLevelRO!Unlzmaer(st, zfh.method, size, stpos, pksize), dir[idx].name);
        /*
        {
          auto fo = VFile("/tmp/300/zip/lzma/zzz.lzma", "w");
          ubyte[1024] buf;
          st.seek(stpos);
          auto left = pksize;
          while (left > 0) {
            uint rdl = cast(uint)(left > buf.length ? buf.length : left);
            //{ import core.stdc.stdio : printf; printf("left=%u; rdl=%u\n", cast(uint)left, rdl); }
            st.rawReadExact(buf[0..rdl]);
            fo.rawWriteExact(buf[0..rdl]);
            left -= rdl;
          }
        }
        assert(0);
        */
      default: break;
    }
    throw new VFSException("unsupported ZIP method");
  }

  void open (VFile fl, const(char)[] prefixpath) {
    version(ziparc_debug) debug(ziparc) import std.stdio : writeln, writefln;

    if (fl.size > 0xffff_ffffu) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("file too big");
    ulong flsize = fl.size;
    if (flsize < EOCDHeader.sizeof) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("file too small");

    // search for "end of central dir"
    auto cdbuf = xalloc!ubyte(65536+EOCDHeader.sizeof+Z64Locator.sizeof);
    scope(exit) xfree(cdbuf);
    ubyte[] buf;
    ulong ubufpos;
    if (flsize < cdbuf.length) {
      fl.seek(0);
      buf = fl.rawRead(cdbuf[0..cast(usize)flsize]);
      if (buf.length != flsize) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
    } else {
      fl.seek(-cast(ulong)cdbuf.length, Seek.End);
      ubufpos = fl.tell;
      buf = fl.rawRead(cdbuf[]);
      if (buf.length != cdbuf.length) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
    }
    int pos;
    for (pos = cast(int)(buf.length-EOCDHeader.sizeof); pos >= 0; --pos) {
      if (buf[pos] == 'P' && buf[pos+1] == 'K' && buf[pos+2] == 5 && buf[pos+3] == 6) break;
    }
    if (pos < 0) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("no central dir end marker found");
    auto eocd = *cast(EOCDHeader*)&buf[pos];
    eocd.fixEndian;
    version(ziparc_debug) debug(ziparc) {
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
      version(ziparc_debug) debug(ziparc) writeln("  ZIP64 archive");
      zip64 = true;
      if (pos < Z64Locator.sizeof) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      auto lt64 = *cast(Z64Locator*)&buf[pos-Z64Locator.sizeof];
      lt64.fixEndian;
      if (lt64.sign != "PK\x06\x07") throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      if (lt64.diskcd != 0 || lt64.diskno > 1) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("multidisk archive");
      version(ziparc_debug) debug(ziparc) writeln("ecd64ofs=", lt64.ecd64ofs);
      if (lt64.ecd64ofs < 0 || lt64.ecd64ofs+EOCD64Header.sizeof > ubufpos+pos-Z64Locator.sizeof) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      EOCD64Header e64 = void;
      fl.seek(lt64.ecd64ofs);
      if (fl.rawRead((&e64)[0..1]).length != 1) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
      e64.fixEndian;
      if (e64.sign != "PK\x06\x06") throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      if (e64.diskno != 0 || e64.diskcd != 0) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("multidisk archive");
      if (e64.diskfileno != e64.fileno) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      if (e64.cdsize >= lt64.ecd64ofs) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      if (e64.cdofs >= lt64.ecd64ofs || e64.cdofs+e64.cdsize > lt64.ecd64ofs) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      cdofs = e64.cdofs;
      cdsize = e64.cdsize;
    } else {
      if (eocd.diskno != 0 || eocd.diskcd != 0) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("multidisk archive");
      //version(ziparc_debug) debug(ziparc) writefln("flsize: 0x%08x  expected: 0x%08x", cast(uint)flsize, cast(uint)(ubufpos+pos+EOCDHeader.sizeof+eocd.cmtsize));
      if (eocd.diskfileno != eocd.fileno) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      // relax it a little
      if (ubufpos+pos+EOCDHeader.sizeof+eocd.cmtsize > flsize) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
      cdofs = eocd.cdofs;
      cdsize = eocd.cdsize;
      if (cdofs >= ubufpos+pos || flsize-cdofs < cdsize) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("corrupted archive");
    }

    // now read central directory
    auto namebuf = xalloc!char(0x10000);
    scope(exit) xfree(namebuf);

    static bool isGoodMethod (uint m) {
      if (m == 0) return true; // store
      if (m == 8) return true; // deflate
      if (m == 6) return true; // implode
      if (m == 1) return true; // shrink
      if (m >= 2 && m <= 5) return true; // reduce
      if (m == 9) return true; // deflate64
      if (m == 14) return true; // lzma
      return false;
    }

    auto bleft = cdsize;
    fl.seek(cdofs);
    CDFileHeader cdfh = void;
    char[4] sign;
    dir.assumeSafeAppend; // yep
    while (bleft > 0) {
      version(ziparc_debug) debug(ziparc) writefln("pos: 0x%08x (%s bytes left)", cast(uint)fl.tell, bleft);
      if (bleft < 4) break;
      if (fl.rawRead(sign[]).length != sign.length) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
      bleft -= 4;
      if (sign[0] != 'P' || sign[1] != 'K') {
        version(ziparc_debug) debug(ziparc) writeln("SIGN: NOT PK!");
        throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid central directory entry");
      }
      version(ziparc_debug) debug(ziparc) writefln("SIGN: 0x%02x 0x%02x", cast(ubyte)sign[2], cast(ubyte)sign[3]);
      // digital signature?
      if (sign[2] == 5 && sign[3] == 5) {
        // yes, skip it
        if (bleft < 2) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
        auto sz = fl.readNum!ushort;
        if (sz > bleft) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid central directory entry");
        fl.seek(sz, Seek.Cur);
        bleft -= sz;
        continue;
      }
      // file item?
      if (sign[2] == 1 && sign[3] == 2) {
        if (bleft < cdfh.sizeof) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
        if (fl.rawRead((&cdfh)[0..1]).length != 1) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
        cdfh.fixEndian;
        bleft -= cdfh.sizeof;
        if (cdfh.disk != 0) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid central directory entry (disk number)");
        if (bleft < cdfh.namelen+cdfh.extlen+cdfh.cmtlen) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid central directory entry");
        // skip bad files
        if (!isGoodMethod(cdfh.method)) {
          version(ziparc_debug) debug(ziparc) writeln("  INVALID: method=", cdfh.method);
          throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid method");
        }
        if (cdfh.namelen == 0 || (cdfh.gflags&0b10_0000_0110_0001) != 0 || (cdfh.attr&0x58) != 0 ||
            cast(long)cdfh.hdrofs+(cdfh.method ? cdfh.pksize : cdfh.size) >= ubufpos+pos)
        {
          version(ziparc_debug) debug(ziparc) writeln("  ignored: method=", cdfh.method);
          // ignore this
          fl.seek(cdfh.namelen+cdfh.extlen+cdfh.cmtlen, Seek.Cur);
          bleft -= cdfh.namelen+cdfh.extlen+cdfh.cmtlen;
          continue;
        }
        FileInfo fi;
        //fi.gflags = cdfh.gflags;
        //fi.packed = (cdfh.method != 0);
        fi.pksize = cdfh.pksize;
        fi.size = cdfh.size;
        fi.hdrofs = cdfh.hdrofs;
        fi.crc32 = cdfh.crc32;
        fi.method = cdfh.method;
        fi.modtime = cdfh.modtime;
        if (cdfh.method == 0) fi.pksize = fi.size;
        // now, this is valid file, so read it's name
        if (fl.rawRead(namebuf[0..cdfh.namelen]).length != cdfh.namelen) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
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
        version(ziparc_debug) debug(ziparc) writefln("name: [%s]; size=0x%08x; pksize=0x%08x", nb[0..nbpos], fi.size, fi.pksize);
        version(ziparc_debug) debug(ziparc) {{
          import std.datetime;
          try {
            writeln("  year: ", cdfh.year, "; month: ", cdfh.month, "; day: ", cdfh.day, "; hour: ", cdfh.hour, "; min: ", cdfh.min, "; sec: ", cdfh.sec);
            writeln("  time: ", SysTime(DateTime(cdfh.year, cdfh.month/*+1*/, cdfh.day+1, cdfh.hour, cdfh.min, cdfh.sec), UTC()));
          } catch (Exception e) {
            writeln("SHIT: ", e.msg);
            throw e;
          }
        }}
        if (zip64 && (fi.size == 0xffff_ffffu || fi.pksize == 0xffff_ffffu || fi.hdrofs == 0xffff_ffffu)) {
          version(ziparc_debug) debug(ziparc) writeln("  ZIP64 record");
          // yep, do it
          bool found = false;
          //Z64Extra z64e = void;
          version(ziparc_debug) debug(ziparc) writeln("extlen=", cdfh.extlen);
          while (cdfh.extlen >= 4) {
            auto eid = fl.readNum!ushort;
            auto esize = fl.readNum!ushort;
            version(ziparc_debug) debug(ziparc) writefln("0x%04x %s", eid, esize);
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
                if (fl.rawRead((&fi.size)[0..1]).length != 1) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
                version(BigEndian) { import std.bitmanip : swapEndian; fi.size = swapEndian(fi.size); }
                esize -= 8;
                //version(ziparc_debug) debug(ziparc) writeln(" size=", fi.size);
              }
              if (fi.pksize == 0xffff_ffffu) {
                if (esize == 0) {
                  //fi.pksize = ulong.max; // this means "get from local header"
                  // read local file header; it's slow, but i don't care
                  /*
                  if (fi.hdrofs == 0xffff_ffffu) throw new /+VFSNamedException!"ZipArchive"+/VFSExceptionArc("invalid zip64 archive (3)");
                  CDFileHeader lfh = void;
                  auto oldpos = fl.tell;
                  fl.seek(fi.hdrofs);
                  if (fl.rawRead((&lfh)[0..1]).length != 1) throw new /+VFSNamedException!"ZipArchive"+/VFSExceptionArc("reading error");
                  assert(0);
                  */
                  throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid zip64 archive (4)");
                } else {
                  if (esize < 8) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid zip64 archive (1)");
                  if (fl.rawRead((&fi.pksize)[0..1]).length != 1) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
                  version(BigEndian) { import std.bitmanip : swapEndian; fi.pksize = swapEndian(fi.pksize); }
                  esize -= 8;
                }
              }
              if (fi.hdrofs == 0xffff_ffffu) {
                if (esize < 8) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid zip64 archive (2)");
                if (fl.rawRead((&fi.hdrofs)[0..1]).length != 1) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("reading error");
                version(BigEndian) { import std.bitmanip : swapEndian; fi.hdrofs = swapEndian(fi.hdrofs); }
                esize -= 8;
              }
              if (esize > 0) fl.seek(esize, Seek.Cur); // skip possible extra data
              //if (z64e.disk != 0) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("invalid central directory entry (disk number)");
              break;
            }
          }
          if (!found) {
            version(ziparc_debug) debug(ziparc) writeln("required zip64 record not found");
            //throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("required zip64 record not found");
            //fi.size = fi.pksize = 0x1_0000_0000Lu; // hack: skip it
            doSkip = true;
          }
        }
        if (!doSkip && nbpos > 0 && nb[nbpos-1] != '/') {
          // add new
          if (dir.length == uint.max) throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("directory too long");
          fi.name = cast(string)nb[0..nbpos]; // this is safe
          dir.arrayAppendUnsafe(fi);
          //version(ziparc_debug) debug(ziparc) writefln("%10s %10s %s %04s/%02s/%02s %02s:%02s:%02s %s", fi.pksize, fi.size, (fi.packed ? "P" : "."), cdfh.year, cdfh.month, cdfh.day, cdfh.hour, cdfh.min, cdfh.sec, fi.name);
        }
        // skip extra and comments
        fl.seek(cdfh.extlen+cdfh.cmtlen, Seek.Cur);
        bleft -= cdfh.namelen+cdfh.extlen+cdfh.cmtlen;
        continue;
      }
      // wtf?!
      throw new /*VFSNamedException!"ZipArchive"*/VFSExceptionArc("unknown central directory entry");
    }
    version(ziparc_debug) debug(ziparc) writeln(dir.length, " files found");
    buildNameHashTable();
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
mixin template DOSDateTimeUtil () {
  @property const nothrow @nogc {
    // unixtime
    uint modtime() @trusted {
      import core.stdc.time : tm, mktime;
      tm xtm = void;
      xtm.tm_sec = sec;
      xtm.tm_min = min;
      xtm.tm_hour = hour;
      xtm.tm_mday = day+1; // this is 1..31
      xtm.tm_mon = month;
      xtm.tm_year = year-1900;
      xtm.tm_wday = xtm.tm_yday = 0;
      xtm.tm_isdst = 0; // ??? -- 1 for local time
      return cast(uint)mktime(&xtm);
    }
    pure @safe {
      ubyte hour () { pragma(inline, true); return cast(ubyte)(((mtime>>11))%24); } // 0..23
      ubyte min () { pragma(inline, true); return cast(ubyte)(((mtime>>5)&0x3f)%60); } // 0..59
      ubyte sec () { pragma(inline, true); return cast(ubyte)(((mtime&0x1f)*2)%60); } // 0..59

      ushort year () { pragma(inline, true); return cast(ushort)((mdate>>9)+1980); }
      ubyte month () { pragma(inline, true); return cast(ubyte)(((mdate>>5)&0x0f ? ((mdate>>5)&0x0f)-1 : 0)%12); } // 0..11
      ubyte day () { pragma(inline, true); return cast(ubyte)((mdate&0x1f ? (mdate&0x1f)-1 : 0)%31); } // 0..30
    }
  }
}


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

  mixin DOSDateTimeUtil;
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

  mixin DOSDateTimeUtil;
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
struct BitReader {
  VFile zfl;
  long zflpos;
  long zflorg;
  long zflsize;
  long zflleft;
  long upkleft;
  long upktotalsize;
  ubyte[1024] inbuf;
  uint ibpos, ibused;
  ubyte gbyte = 1;
  bool ateof;

  void setup (VFile afl, long apos, long apksize, long aupksize) {
    zfl = afl;
    gbyte = 1;
    ibpos = ibused = 0;
    ateof = (aupksize == 0);
    zflpos = zflorg = apos;
    zflsize = apksize;
    upktotalsize = aupksize;
    upkleft = 0;
  }

  void reset () {
    gbyte = 1;
    ibpos = ibused = 0;
    ateof = false;
    zflpos = zflorg;
    zflleft = zflsize;
    upkleft = upktotalsize;
  }

  void close () { zfl = VFile.init; }

  // 0: eof
  uint readNewBuffer () {
    ibpos = ibused = 0;
    auto rd = cast(uint)(zflleft > inbuf.length ? inbuf.length : zflleft);
    if (rd == 0) { ateof = true; return 0; }
    zfl.seek(zflpos);
    zfl.rawReadExact(inbuf[0..rd]);
    ibused = rd;
    zflpos += rd;
    zflleft -= rd;
    return rd;
  }

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
    }
    return inbuf.ptr[ibpos++];
  }

  ubyte readPackedBit () {
    pragma(inline, true);
    ubyte res = (gbyte&1);
    gbyte >>= 1;
    if (gbyte == 0) {
      gbyte = readPackedByte!ubyte();
      res = gbyte&1;
      gbyte = (gbyte>>1)|0x80;
    }
    return res;
  }

  ubyte readPackedBits (ubyte count) {
    ubyte res = 0, mask = 1;
    //if (count > 8) assert(0, "wtf?!");
    while (count--) {
      if (readPackedBit()) res |= mask;
      mask <<= 1;
    }
    return res;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// slow and stupid "implode" unpacker
// based on the code from gunzip.c by Pasi Ojala, a1bert@iki.fi (http://www.iki.fi/a1bert/)
struct Exploder {
  public enum InitUpkBufSize = 512; // way too much

  BitReader br;

  static struct HufNode {
    ushort b0; // 0-branch value + leaf node flag
    ushort b1; // 1-branch value + leaf node flag
    //HufNode* jump; // 1-branch jump address
    usize jumpptr; // hide this from GC
    @property nothrow @trusted @nogc {
      HufNode* jump () const { pragma(inline, true); return cast(HufNode*)jumpptr; }
      void jump (HufNode* v) { pragma(inline, true); jumpptr = cast(usize)v; }
    }
  }

  enum LITERALS = 288;

  HufNode[LITERALS] literalTree;
  HufNode[32] distanceTree;
  //HufNode* places = null;

  HufNode[64] impDistanceTree;
  HufNode[64] impLengthTree;
  ubyte len = 0;
  short[17] fpos = 0;
  //int* flens;
  short fmax;

  int[256] ll;
  alias flens = ll;

  int minMatchLen = 3;
  uint gflags;

  ubyte[32768] buf32k;
  uint bIdx;

public:
  void close () { br.close(); }

  void setup (VFile fl, ulong agflags, long apos, uint apksize, uint aupksize) {
    br.setup(fl, apos, apksize, aupksize);
    gflags = cast(uint)agflags;
    reset();
  }

  void reset () {
    br.reset();
    buf32k[] = 0;
    bIdx = 0;
    if (br.upktotalsize == 0) return;
    if ((gflags&4) != 0) {
      // 3 trees: literals, lengths, distance top 6
      minMatchLen = 3;
      createTree(literalTree.ptr, decodeSF(ll.ptr), ll.ptr);
    } else {
      // 2 trees: lengths, distance top 6
      minMatchLen = 2;
    }
    createTree(impLengthTree.ptr, decodeSF(ll.ptr), ll.ptr);
    createTree(impDistanceTree.ptr, decodeSF(ll.ptr), ll.ptr);
  }

  bool unpackChunk (scope VStreamDecoderLowLevelROPutBytesDg putUB) {
    if (br.upkleft == 0) return false; // packed file EOF
    int c = br.readPackedBits(1);
    if (c) {
      // literal data
      if ((gflags&4) != 0) {
        c = decodeSFValue(literalTree.ptr);
      } else {
        c = br.readPackedBits(8);
      }
      //bufferUpkByte(cast(ubyte)c);
      buf32k.ptr[bIdx++] = cast(ubyte)c;
      bIdx &= 0x7fff;
      putUB(cast(ubyte)c);
    } else {
      int dist;
      if ((gflags&2) != 0) {
        // 8k dictionary
        dist = br.readPackedBits(7);
        c = decodeSFValue(impDistanceTree.ptr);
        dist |= (c<<7);
      } else {
        // 4k dictionary
        dist = br.readPackedBits(6);
        c = decodeSFValue(impDistanceTree.ptr);
        dist |= (c<<6);
      }
      int len = decodeSFValue(impLengthTree.ptr);
      if (len == 63) len += br.readPackedBits(8);
      len += minMatchLen;
      ++dist;
      foreach (immutable i; 0..len) {
        ubyte b = buf32k.ptr[(bIdx-dist)&0x7fff];
        //bufferUpkByte(b);
        buf32k.ptr[bIdx++] = b;
        bIdx &= 0x7fff;
        putUB(b);
      }
    }
    return true;
  }

private:
  // decode one symbol of the data
  int decodeSFValue (const(HufNode)* tree) {
    for (;;) {
      if (!br.readPackedBit()) {
        // only the decision is reversed!
        if ((tree.b1&0x8000) == 0) return tree.b1; // If leaf node, return data
        tree = tree.jump;
      } else {
        if ((tree.b0&0x8000) == 0) return tree.b0; // If leaf node, return data
        ++tree;
      }
    }
    return -1;
  }

  int decodeSF (int* table) {
    int v = 0;
    immutable n = br.readPackedByte()+1;
    foreach (immutable i; 0..n) {
      auto a = br.readPackedByte();
      auto nv = ((a>>4)&15)+1;
      auto bl = (a&15)+1;
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
  /* Note: Imploding could use the lighter huffman tree routines, as the
         max number of entries is 256. But too much code would need to
         be duplicated.
   */
  void createTree (HufNode* currentTree, int numval, int* lengths) {
    // create the Huffman decode tree/table
    HufNode* places = currentTree;
    //flens = lengths;
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

      HufNode* curplace = places;
      int tmp;

      if (len == 17) throw new Exception("invalid huffman tree");
      ++places;
      ++len;

      tmp = isPat();
      if (tmp >= 0) {
        curplace.b0 = cast(ushort)tmp; // leaf cell for 0-bit
      } else {
        // not a leaf cell
        curplace.b0 = 0x8000;
        rec();
      }
      tmp = isPat();
      if (tmp >= 0) {
        curplace.b1 = cast(ushort)tmp; // leaf cell for 1-bit
        curplace.jump = null; // Just for the display routine
      } else {
        // not a leaf cell
        curplace.b1 = 0x8000;
        curplace.jump = places;
        rec();
      }
      --len;
    }

    rec();
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct Deshrinker {
  public enum InitUpkBufSize = 8192; // way too much

  // HSIZE is defined as 2^13 (8192) in unzip.h
  enum HSIZE     = 8192;
  enum BOGUSCODE = 256;
  enum CODE_MASK = HSIZE-1;  // 0x1fff (lower bits are parent's index)
  enum FREE_CODE = HSIZE;    // 0x2000 (code is unused or was cleared)
  enum HAS_CHILD = HSIZE<<1; // 0x4000 (code has a child--do not clear)

  BitReader br;

  ushort[HSIZE] parent;
  ubyte[HSIZE] value;
  ubyte[HSIZE] stack;

  ubyte* newstr;
  int len;
  char KwKwK, codesize = 1; // start at 9 bits/code
  short code, oldcode, freecode, curcode;
  bool inited = false;

public:
  void close () { br.close(); }

  void setup (VFile fl, ulong agflags, long apos, uint apksize, uint aupksize) {
    br.setup(fl, apos, apksize, aupksize);
    reset();
  }

  void reset () {
    br.reset();
    if (br.upktotalsize == 0) return;
    codesize = 1; // start at 9 bits/code
    freecode = BOGUSCODE;
    for (code = 0; code < BOGUSCODE; code++) {
      value[code] = cast(ubyte)code;
      parent[code] = BOGUSCODE;
    }
    for (code = BOGUSCODE+1; code < HSIZE; code++) parent[code] = FREE_CODE;
    inited = false;
  }

  bool unpackChunk (scope VStreamDecoderLowLevelROPutBytesDg putUB) {
    if (br.upkleft == 0) return false; // packed file EOF
    if (!inited) {
      inited = true;
      oldcode = cast(short)br.readPackedBits(8);
      oldcode |= (br.readPackedBits(codesize)<<8);
      putUB(cast(ubyte)oldcode);
    }
    for (;;) {
      code = cast(short)br.readPackedBits(8);
      code |= (br.readPackedBits(codesize)<<8);
      if (code == BOGUSCODE) {
        // possible to have consecutive escapes?
        code = cast(short)br.readPackedBits(8);
        code |= (br.readPackedBits(codesize)<<8);
        if (code == 1) {
          ++codesize;
        } else if (code == 2) {
          // clear leafs (nodes with no children)

          // first loop: mark each parent as such
          for (code = BOGUSCODE+1; code < HSIZE; ++code) {
            curcode = (parent[code]&CODE_MASK);
            if (curcode > BOGUSCODE) parent[curcode] |= HAS_CHILD; // set parent's child-bit
          }
          // second loop:  clear all nodes *not* marked as parents; reset flag bits
          for (code = BOGUSCODE+1;  code < HSIZE;  ++code) {
            if (parent[code]&HAS_CHILD) {
              // just clear child-bit
              parent[code] &= ~HAS_CHILD;
            } else {
              // leaf: lose it
              parent[code] = FREE_CODE;
            }
          }
          freecode = BOGUSCODE;
        }
        continue;
      }

      newstr = &stack[HSIZE-1];
      curcode = code;

      if (parent[curcode] == FREE_CODE) {
        KwKwK = 1;
        --newstr; // last character will be same as first character
        curcode = oldcode;
        len = 1;
      } else {
        KwKwK = 0;
        len = 0;
      }

      do {
        *newstr-- = value[curcode];
        ++len;
        curcode = (parent[curcode]&CODE_MASK);
      } while (curcode != BOGUSCODE);

      ++newstr;
      if (KwKwK) stack[HSIZE-1] = *newstr;

      do {
        ++freecode;
      } while (parent[freecode] != FREE_CODE);

      parent[freecode] = oldcode;
      value[freecode] = *newstr;
      oldcode = code;

      version(ziparc_debug) debug(ziparc) { import core.stdc.stdio : printf; printf("deshrinker: len=%d\n", len); }
      while (len--) {
        putUB(*newstr);
        ++newstr;
      }

      break;
    }

    return true;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
struct Inductor {
  public enum InitUpkBufSize = 1024; // way too much

  BitReader br;

  ubyte[16384] buf32k;

  ubyte[32][256] S;
  ubyte[256] N;
  static immutable ubyte[64] B = [
    0,
    1,1,2,2,3,3,3,3, 4,4,4,4,4,4,4,4,
    5,5,5,5,5,5,5,5, 5,5,5,5,5,5,5,5,
    6
  ];

  ubyte level;
  int lastC = 0;
  short nchar;
  short state = 0;
  int upslen = 0, upsdist = 0;
  uint bIdx = 0;

  enum DLE = 144;

public:
  void close () { br.close(); }

  void setup (VFile fl, ulong agflags, long apos, uint apksize, uint aupksize) {
    br.setup(fl, apos, apksize, aupksize);
    if (agflags < 2) agflags = 2; else if (agflags > 5) agflags = 5;
    level = cast(ubyte)(agflags-2); //FIXME: don't abuse agflags
    reset();
  }

  void reset () {
    br.reset();
    if (br.upktotalsize == 0) return;
    buf32k[] = 0;
    bIdx = 0;
    state = 0;
    lastC = 0;
    upslen = 0;
    upsdist = 0;
    loadFollowers();
  }

  bool unpackChunk (scope VStreamDecoderLowLevelROPutBytesDg pdg) {
    if (br.upkleft == 0) return false; // packed file EOF
    void putUB (uint c) {
      buf32k[bIdx++] = cast(ubyte)c;
      bIdx &= 0x3fff;
      pdg(cast(ubyte)c);
    }
    uint c;
    if (!N[lastC]) {
      c = br.readPackedBits(8);
    } else {
      if (br.readPackedBits(1)) {
        c = br.readPackedBits(8);
      } else {
        c = 0;
        if (N[lastC] != 0) c = br.readPackedBits(B[N[lastC]]);
        c = S[lastC][c];
      }
    }
    lastC = c;
    switch (state) {
      case 0:
        if (c != DLE) putUB(c); else state = 1;
        break;
      case 1:
        if (c) {
          upsdist = (c>>(7-level))<<8;
          upslen = c&(0x7f>>level);
          state = (upslen == (0x7f>>level) ? 2 : 3);
        } else {
          putUB(144);
          state = 0;
        }
        break;
      case 2:
        upslen += c;
        state = 3;
        break;
      case 3:
        upsdist += c+1;
        upslen += 3;
        while (upslen--) putUB(buf32k[(bIdx-upsdist)&0x3fff]);
        state = 0;
        break;
      default:
    }
    return true;
  }

private:
  void loadFollowers () {
    for (int j = 255; j >= 0; --j) {
      N[j] = cast(ubyte)br.readPackedBits(6);
      if (N[j] > 32) { /*errfp.writef("Follower set %d too large: %d\n", j, N[j]);*/ N[j] = 32; }
      for (int i = 0; i < N[j]; ++i) S[j][i] = cast(ubyte)br.readPackedBits(8);
    }
  }
}


// ////////////////////////////////////////////////////////////////////////// //
/* inflate9.h -- internal inflate state definition
 * Copyright (C) 1995-2003 Mark Adler
 * For conditions of distribution and use, see copyright notice in zlib.h
 */

/* WARNING: this file should *not* be used by applications. It is
   part of the implementation of the compression library and is
   subject to change. Applications should only use zlib.h.
 */

enum {
  Z_OK = 0,
  Z_STREAM_ERROR = -1,
  Z_MEM_ERROR = -2,
  Z_BUF_ERROR = -3,
  Z_STREAM_END = -4,
  Z_DATA_ERROR = -5,
}

enum MAXBITS = 15;

static immutable string inflate9_copyright = " inflate9 1.2.8 Copyright 1995-2013 Mark Adler ";
/*
  If you use the zlib library in a product, an acknowledgment is welcome
  in the documentation of your product. If for some reason you cannot
  include such an acknowledgment, I would appreciate that you keep this
  copyright string in the executable of your product.
 */


alias c_ulong = uint;

struct zd64_stream {
  // /*const(ubyte)* */ubyte* next_in; // next input byte
  mixin VFSHiddenPointerHelper!(ubyte, "next_in");
  uint avail_in; // number of bytes available at next_in
  //string msg; // last error message, NULL if no error
  //private void* state; // not visible by applications
  private mixin VFSHiddenPointerHelper!(void, "state");
}

// Possible inflate modes between inflate() calls
alias inflate_mode = ubyte;
enum /*inflate_mode*/ {
  TYPE, // i: waiting for type bits, including last-flag bit
  STORED, // i: waiting for stored size (length and complement)
  TABLE, // i: waiting for dynamic block table lengths
  LEN, // i: waiting for length/lit code
  DONE, // finished check, done -- remain here until reset
  BAD, // got a data error -- remain here until reset
}

/*
    State transitions between above modes -

    (most modes can go to the BAD mode -- not shown for clarity)

    Read deflate blocks:
            TYPE -> STORED or TABLE or LEN or DONE
            STORED -> TYPE
            TABLE -> LENLENS -> CODELENS -> LEN
    Read deflate codes:
                LEN -> LEN or TYPE
 */

// state maintained between inflate() calls.  Approximately 7K bytes.
struct inflate_state {
  ubyte[WSIZE] window_; // sliding window
  // dynamic table building
  uint ncode; // number of code length code lengths
  uint nlen; // number of length code lengths
  uint ndist; // number of distance code lengths
  uint have_; // number of code lengths in lens[]
  code* next_; // next available space in codes[]
  ushort[320] lens; // temporary storage for code lengths
  ushort[288] work; // work area for code table building
  code[ENOUGH] codes; // space for code tables
  // other vars
  /*const(ubyte)* */ubyte* next; // next input
  ubyte* put; // next output
  uint have; // available input
  uint left; // available output
  inflate_mode mode; // current inflate mode
  int lastblock; // true if processing last block
  int wrap; // true if the window has wrapped
  ubyte* window; // allocated sliding window, if needed
  uint hold; // bit buffer
  uint bits; // bits in bit buffer
  uint extra; // extra bits needed
  uint length; // literal or length of data to copy
  uint offset; // distance back to copy string from
  uint copy; // number of stored or match bytes to copy
  ubyte* from; // where to copy match bytes from
  const(code)* lencode; // starting table for length/literal codes
  const(code)* distcode; // starting table for distance codes
  uint lenbits; // index bits for lencode
  uint distbits; // index bits for distcode
  code here; // current decoding table entry
  code last; // parent table entry
  uint len; // length to copy for repeats, bits to drop
  int ret; // return code
}


/* inftree9.h -- header to use inftree9.c
 * Copyright (C) 1995-2008 Mark Adler
 * For conditions of distribution and use, see copyright notice in zlib.h
 */

/* WARNING: this file should *not* be used by applications. It is
   part of the implementation of the compression library and is
   subject to change. Applications should only use zlib.h.
 */

/* Structure for decoding tables.  Each entry provides either the
   information needed to do the operation requested by the code that
   indexed that table entry, or it provides a pointer to another
   table that indexes more bits of the code.  op indicates whether
   the entry is a pointer to another table, a literal, a length or
   distance, an end-of-block, or an invalid code.  For a table
   pointer, the low four bits of op is the number of index bits of
   that table.  For a length or distance, the low four bits of op
   is the number of extra bits to get after the code.  bits is
   the number of bits in this code or part of the code to drop off
   of the bit buffer.  val is the actual byte to output in the case
   of a literal, the base length or distance, or the offset from
   the current table to the next table.  Each entry is four bytes. */
struct code {
  ubyte op; // operation, extra bits, table bits
  ubyte bits; // bits in this part of the code
  ushort val; // offset in table or code value
}

/* op values as set by inflate_table():
    00000000 - literal
    0000tttt - table link, tttt != 0 is the number of table index bits
    100eeeee - length or distance, eeee is the number of extra bits
    01100000 - end of block
    01000000 - invalid code
 */

/* Maximum size of the dynamic table.  The maximum number of code structures is
   1446, which is the sum of 852 for literal/length codes and 594 for distance
   codes.  These values were found by exhaustive searches using the program
   examples/enough.c found in the zlib distribtution.  The arguments to that
   program are the number of symbols, the initial root table size, and the
   maximum bit length of a code.  "enough 286 9 15" for literal/length codes
   returns returns 852, and "enough 32 6 15" for distance codes returns 594.
   The initial root table size (9 or 6) is found in the fifth argument of the
   inflate_table() calls in infback9.c.  If the root table size is changed,
   then these maximum sizes would be need to be recalculated and updated. */
enum ENOUGH_LENS = 852;
enum ENOUGH_DISTS = 594;
enum ENOUGH = ENOUGH_LENS+ENOUGH_DISTS;

// Type of code to build for inflate_table9()
alias codetype = ubyte;
enum /*codetype*/ {
  CODES,
  LENS,
  DISTS,
}

/* inffix9.h -- table for decoding deflate64 fixed codes
 * Generated automatically by makefixed9().
 */

/* WARNING: this file should *not* be used by applications.
   It is part of the implementation of this library and is
   subject to change. Applications should only use zlib.h.
 */

static immutable code[512] lenfix = [
  code(96,7,0),code(0,8,80),code(0,8,16),code(132,8,115),code(130,7,31),code(0,8,112),
  code(0,8,48),code(0,9,192),code(128,7,10),code(0,8,96),code(0,8,32),code(0,9,160),
  code(0,8,0),code(0,8,128),code(0,8,64),code(0,9,224),code(128,7,6),code(0,8,88),
  code(0,8,24),code(0,9,144),code(131,7,59),code(0,8,120),code(0,8,56),code(0,9,208),
  code(129,7,17),code(0,8,104),code(0,8,40),code(0,9,176),code(0,8,8),code(0,8,136),
  code(0,8,72),code(0,9,240),code(128,7,4),code(0,8,84),code(0,8,20),code(133,8,227),
  code(131,7,43),code(0,8,116),code(0,8,52),code(0,9,200),code(129,7,13),code(0,8,100),
  code(0,8,36),code(0,9,168),code(0,8,4),code(0,8,132),code(0,8,68),code(0,9,232),
  code(128,7,8),code(0,8,92),code(0,8,28),code(0,9,152),code(132,7,83),code(0,8,124),
  code(0,8,60),code(0,9,216),code(130,7,23),code(0,8,108),code(0,8,44),code(0,9,184),
  code(0,8,12),code(0,8,140),code(0,8,76),code(0,9,248),code(128,7,3),code(0,8,82),
  code(0,8,18),code(133,8,163),code(131,7,35),code(0,8,114),code(0,8,50),code(0,9,196),
  code(129,7,11),code(0,8,98),code(0,8,34),code(0,9,164),code(0,8,2),code(0,8,130),
  code(0,8,66),code(0,9,228),code(128,7,7),code(0,8,90),code(0,8,26),code(0,9,148),
  code(132,7,67),code(0,8,122),code(0,8,58),code(0,9,212),code(130,7,19),code(0,8,106),
  code(0,8,42),code(0,9,180),code(0,8,10),code(0,8,138),code(0,8,74),code(0,9,244),
  code(128,7,5),code(0,8,86),code(0,8,22),code(65,8,0),code(131,7,51),code(0,8,118),
  code(0,8,54),code(0,9,204),code(129,7,15),code(0,8,102),code(0,8,38),code(0,9,172),
  code(0,8,6),code(0,8,134),code(0,8,70),code(0,9,236),code(128,7,9),code(0,8,94),
  code(0,8,30),code(0,9,156),code(132,7,99),code(0,8,126),code(0,8,62),code(0,9,220),
  code(130,7,27),code(0,8,110),code(0,8,46),code(0,9,188),code(0,8,14),code(0,8,142),
  code(0,8,78),code(0,9,252),code(96,7,0),code(0,8,81),code(0,8,17),code(133,8,131),
  code(130,7,31),code(0,8,113),code(0,8,49),code(0,9,194),code(128,7,10),code(0,8,97),
  code(0,8,33),code(0,9,162),code(0,8,1),code(0,8,129),code(0,8,65),code(0,9,226),
  code(128,7,6),code(0,8,89),code(0,8,25),code(0,9,146),code(131,7,59),code(0,8,121),
  code(0,8,57),code(0,9,210),code(129,7,17),code(0,8,105),code(0,8,41),code(0,9,178),
  code(0,8,9),code(0,8,137),code(0,8,73),code(0,9,242),code(128,7,4),code(0,8,85),
  code(0,8,21),code(144,8,3),code(131,7,43),code(0,8,117),code(0,8,53),code(0,9,202),
  code(129,7,13),code(0,8,101),code(0,8,37),code(0,9,170),code(0,8,5),code(0,8,133),
  code(0,8,69),code(0,9,234),code(128,7,8),code(0,8,93),code(0,8,29),code(0,9,154),
  code(132,7,83),code(0,8,125),code(0,8,61),code(0,9,218),code(130,7,23),code(0,8,109),
  code(0,8,45),code(0,9,186),code(0,8,13),code(0,8,141),code(0,8,77),code(0,9,250),
  code(128,7,3),code(0,8,83),code(0,8,19),code(133,8,195),code(131,7,35),code(0,8,115),
  code(0,8,51),code(0,9,198),code(129,7,11),code(0,8,99),code(0,8,35),code(0,9,166),
  code(0,8,3),code(0,8,131),code(0,8,67),code(0,9,230),code(128,7,7),code(0,8,91),
  code(0,8,27),code(0,9,150),code(132,7,67),code(0,8,123),code(0,8,59),code(0,9,214),
  code(130,7,19),code(0,8,107),code(0,8,43),code(0,9,182),code(0,8,11),code(0,8,139),
  code(0,8,75),code(0,9,246),code(128,7,5),code(0,8,87),code(0,8,23),code(77,8,0),
  code(131,7,51),code(0,8,119),code(0,8,55),code(0,9,206),code(129,7,15),code(0,8,103),
  code(0,8,39),code(0,9,174),code(0,8,7),code(0,8,135),code(0,8,71),code(0,9,238),
  code(128,7,9),code(0,8,95),code(0,8,31),code(0,9,158),code(132,7,99),code(0,8,127),
  code(0,8,63),code(0,9,222),code(130,7,27),code(0,8,111),code(0,8,47),code(0,9,190),
  code(0,8,15),code(0,8,143),code(0,8,79),code(0,9,254),code(96,7,0),code(0,8,80),
  code(0,8,16),code(132,8,115),code(130,7,31),code(0,8,112),code(0,8,48),code(0,9,193),
  code(128,7,10),code(0,8,96),code(0,8,32),code(0,9,161),code(0,8,0),code(0,8,128),
  code(0,8,64),code(0,9,225),code(128,7,6),code(0,8,88),code(0,8,24),code(0,9,145),
  code(131,7,59),code(0,8,120),code(0,8,56),code(0,9,209),code(129,7,17),code(0,8,104),
  code(0,8,40),code(0,9,177),code(0,8,8),code(0,8,136),code(0,8,72),code(0,9,241),
  code(128,7,4),code(0,8,84),code(0,8,20),code(133,8,227),code(131,7,43),code(0,8,116),
  code(0,8,52),code(0,9,201),code(129,7,13),code(0,8,100),code(0,8,36),code(0,9,169),
  code(0,8,4),code(0,8,132),code(0,8,68),code(0,9,233),code(128,7,8),code(0,8,92),
  code(0,8,28),code(0,9,153),code(132,7,83),code(0,8,124),code(0,8,60),code(0,9,217),
  code(130,7,23),code(0,8,108),code(0,8,44),code(0,9,185),code(0,8,12),code(0,8,140),
  code(0,8,76),code(0,9,249),code(128,7,3),code(0,8,82),code(0,8,18),code(133,8,163),
  code(131,7,35),code(0,8,114),code(0,8,50),code(0,9,197),code(129,7,11),code(0,8,98),
  code(0,8,34),code(0,9,165),code(0,8,2),code(0,8,130),code(0,8,66),code(0,9,229),
  code(128,7,7),code(0,8,90),code(0,8,26),code(0,9,149),code(132,7,67),code(0,8,122),
  code(0,8,58),code(0,9,213),code(130,7,19),code(0,8,106),code(0,8,42),code(0,9,181),
  code(0,8,10),code(0,8,138),code(0,8,74),code(0,9,245),code(128,7,5),code(0,8,86),
  code(0,8,22),code(65,8,0),code(131,7,51),code(0,8,118),code(0,8,54),code(0,9,205),
  code(129,7,15),code(0,8,102),code(0,8,38),code(0,9,173),code(0,8,6),code(0,8,134),
  code(0,8,70),code(0,9,237),code(128,7,9),code(0,8,94),code(0,8,30),code(0,9,157),
  code(132,7,99),code(0,8,126),code(0,8,62),code(0,9,221),code(130,7,27),code(0,8,110),
  code(0,8,46),code(0,9,189),code(0,8,14),code(0,8,142),code(0,8,78),code(0,9,253),
  code(96,7,0),code(0,8,81),code(0,8,17),code(133,8,131),code(130,7,31),code(0,8,113),
  code(0,8,49),code(0,9,195),code(128,7,10),code(0,8,97),code(0,8,33),code(0,9,163),
  code(0,8,1),code(0,8,129),code(0,8,65),code(0,9,227),code(128,7,6),code(0,8,89),
  code(0,8,25),code(0,9,147),code(131,7,59),code(0,8,121),code(0,8,57),code(0,9,211),
  code(129,7,17),code(0,8,105),code(0,8,41),code(0,9,179),code(0,8,9),code(0,8,137),
  code(0,8,73),code(0,9,243),code(128,7,4),code(0,8,85),code(0,8,21),code(144,8,3),
  code(131,7,43),code(0,8,117),code(0,8,53),code(0,9,203),code(129,7,13),code(0,8,101),
  code(0,8,37),code(0,9,171),code(0,8,5),code(0,8,133),code(0,8,69),code(0,9,235),
  code(128,7,8),code(0,8,93),code(0,8,29),code(0,9,155),code(132,7,83),code(0,8,125),
  code(0,8,61),code(0,9,219),code(130,7,23),code(0,8,109),code(0,8,45),code(0,9,187),
  code(0,8,13),code(0,8,141),code(0,8,77),code(0,9,251),code(128,7,3),code(0,8,83),
  code(0,8,19),code(133,8,195),code(131,7,35),code(0,8,115),code(0,8,51),code(0,9,199),
  code(129,7,11),code(0,8,99),code(0,8,35),code(0,9,167),code(0,8,3),code(0,8,131),
  code(0,8,67),code(0,9,231),code(128,7,7),code(0,8,91),code(0,8,27),code(0,9,151),
  code(132,7,67),code(0,8,123),code(0,8,59),code(0,9,215),code(130,7,19),code(0,8,107),
  code(0,8,43),code(0,9,183),code(0,8,11),code(0,8,139),code(0,8,75),code(0,9,247),
  code(128,7,5),code(0,8,87),code(0,8,23),code(77,8,0),code(131,7,51),code(0,8,119),
  code(0,8,55),code(0,9,207),code(129,7,15),code(0,8,103),code(0,8,39),code(0,9,175),
  code(0,8,7),code(0,8,135),code(0,8,71),code(0,9,239),code(128,7,9),code(0,8,95),
  code(0,8,31),code(0,9,159),code(132,7,99),code(0,8,127),code(0,8,63),code(0,9,223),
  code(130,7,27),code(0,8,111),code(0,8,47),code(0,9,191),code(0,8,15),code(0,8,143),
  code(0,8,79),code(0,9,255),
];

static immutable code[32] distfix = [
  code(128,5,1),code(135,5,257),code(131,5,17),code(139,5,4097),code(129,5,5),
  code(137,5,1025),code(133,5,65),code(141,5,16385),code(128,5,3),code(136,5,513),
  code(132,5,33),code(140,5,8193),code(130,5,9),code(138,5,2049),code(134,5,129),
  code(142,5,32769),code(128,5,2),code(135,5,385),code(131,5,25),code(139,5,6145),
  code(129,5,7),code(137,5,1537),code(133,5,97),code(141,5,24577),code(128,5,4),
  code(136,5,769),code(132,5,49),code(140,5,12289),code(130,5,13),code(138,5,3073),
  code(134,5,193),code(142,5,49153),
];


// permutation of code lengths
static immutable ushort[19] order = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];


/*
   Build a set of tables to decode the provided canonical Huffman code.
   The code lengths are lens[0..codes-1].  The result starts at *table,
   whose indices are 0..2^bits-1.  work is a writable array of at least
   lens shorts, which is used as a work area.  type is the type of code
   to be generated, CODES, LENS, or DISTS.  On return, zero is success,
   -1 is an invalid code, and +1 means that ENOUGH isn't enough.  table
   on return points to the next available entry's address.  bits is the
   requested root table index bits, and on return it is the actual root
   table index bits.  It will differ if the request is greater than the
   longest code or if it is less than the shortest code.
 */
int inflate_table9 (codetype type, ushort* lens, uint codes, code** table, uint* bits, ushort* work) {
  uint len; // a code's length in bits
  uint sym; // index of code symbols
  uint min, max; // minimum and maximum code lengths
  uint root; // number of index bits for root table
  uint curr; // number of index bits for current table
  uint drop; // code bits to drop for sub-table
  int left; // number of prefix codes available
  uint used; // code entries in table used
  uint huff; // Huffman code
  uint incr; // for incrementing code, index
  uint fill; // index for replicating entries
  uint low; // low bits for current root entry
  uint mask; // mask for low root bits
  code this_; // table entry for duplication
  code* next; // next available space in table
  const(ushort)* base; // base value table to use
  const(ushort)* extra; // extra bits table to use
  int end; // use base and extra for symbol > end
  ushort[MAXBITS+1] count; // number of codes of each length
  ushort[MAXBITS+1] offs; // offsets in table for each length
  // Length codes 257..285 base
  static immutable ushort[31] lbase = [
    3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17,
    19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115,
    131, 163, 195, 227, 3, 0, 0];
  // Length codes 257..285 extra
  static immutable ushort[31] lext = [
    128, 128, 128, 128, 128, 128, 128, 128, 129, 129, 129, 129,
    130, 130, 130, 130, 131, 131, 131, 131, 132, 132, 132, 132,
    133, 133, 133, 133, 144, 72, 78];
  // Distance codes 0..31 base
  static immutable ushort[32] dbase = [
    1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49,
    65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073,
    4097, 6145, 8193, 12289, 16385, 24577, 32769, 49153];
  // Distance codes 0..31 extra
  static immutable ushort[32] dext = [
    128, 128, 128, 128, 129, 129, 130, 130, 131, 131, 132, 132,
    133, 133, 134, 134, 135, 135, 136, 136, 137, 137, 138, 138,
    139, 139, 140, 140, 141, 141, 142, 142];

  /*
     Process a set of code lengths to create a canonical Huffman code.  The
     code lengths are lens[0..codes-1].  Each length corresponds to the
     symbols 0..codes-1.  The Huffman code is generated by first sorting the
     symbols by length from short to long, and retaining the symbol order
     for codes with equal lengths.  Then the code starts with all zero bits
     for the first code of the shortest length, and the codes are integer
     increments for the same length, and zeros are appended as the length
     increases.  For the deflate format, these bits are stored backwards
     from their more natural integer increment ordering, and so when the
     decoding tables are built in the large loop below, the integer codes
     are incremented backwards.

     This routine assumes, but does not check, that all of the entries in
     lens[] are in the range 0..MAXBITS.  The caller must assure this.
     1..MAXBITS is interpreted as that code length.  zero means that that
     symbol does not occur in this code.

     The codes are sorted by computing a count of codes for each length,
     creating from that a table of starting indices for each length in the
     sorted table, and then entering the symbols in order in the sorted
     table.  The sorted table is work[], with that space being provided by
     the caller.

     The length counts are used for other purposes as well, i.e. finding
     the minimum and maximum length codes, determining if there are any
     codes at all, checking for a valid set of lengths, and looking ahead
     at length counts to determine sub-table sizes when building the
     decoding tables.
   */

  // accumulate lengths for codes (assumes lens[] all in 0..MAXBITS)
  for (len = 0; len <= MAXBITS; len++) count[len] = 0;
  for (sym = 0; sym < codes; sym++) count[lens[sym]]++;

  // bound code lengths, force root to be within code lengths
  root = *bits;
  for (max = MAXBITS; max >= 1; max--) if (count[max] != 0) break;
  if (root > max) root = max;
  if (max == 0) return -1; // no codes!
  for (min = 1; min <= MAXBITS; min++) if (count[min] != 0) break;
  if (root < min) root = min;

  // check for an over-subscribed or incomplete set of lengths
  left = 1;
  for (len = 1; len <= MAXBITS; len++) {
    left <<= 1;
    left -= count[len];
    if (left < 0) return -1; // over-subscribed
  }
  if (left > 0 && (type == CODES || max != 1)) return -1; // incomplete set

  // generate offsets into symbol table for each length for sorting
  offs[1] = 0;
  for (len = 1; len < MAXBITS; len++) offs[len+1] = cast(ushort)(offs[len]+count[len]);

  // sort symbols by length, by symbol order within each length
  for (sym = 0; sym < codes; sym++) if (lens[sym] != 0) work[offs[lens[sym]]++] = cast(ushort)sym;

  /*
     Create and fill in decoding tables.  In this loop, the table being
     filled is at next and has curr index bits.  The code being used is huff
     with length len.  That code is converted to an index by dropping drop
     bits off of the bottom.  For codes where len is less than drop+curr,
     those top drop+curr-len bits are incremented through all values to
     fill the table with replicated entries.

     root is the number of index bits for the root table.  When len exceeds
     root, sub-tables are created pointed to by the root entry with an index
     of the low root bits of huff.  This is saved in low to check for when a
     new sub-table should be started.  drop is zero when the root table is
     being filled, and drop is root when sub-tables are being filled.

     When a new sub-table is needed, it is necessary to look ahead in the
     code lengths to determine what size sub-table is needed.  The length
     counts are used for this, and so count[] is decremented as codes are
     entered in the tables.

     used keeps track of how many table entries have been allocated from the
     provided *table space.  It is checked for LENS and DIST tables against
     the constants ENOUGH_LENS and ENOUGH_DISTS to guard against changes in
     the initial root table size constants.  See the comments in inftree9.h
     for more information.

     sym increments through all symbols, and the loop terminates when
     all codes of length max, i.e. all codes, have been processed.  This
     routine permits incomplete codes, so another loop after this one fills
     in the rest of the decoding tables with invalid code markers.
   */

  // set up for code type
  switch (type) {
    case CODES:
      base = extra = work; // dummy value--not used
      end = 19;
      break;
    case LENS:
      base = lbase.ptr;
      base -= 257;
      extra = lext.ptr;
      extra -= 257;
      end = 256;
      break;
    default: // DISTS
      base = dbase.ptr;
      extra = dext.ptr;
      end = -1;
      break;
  }

  // initialize state for loop
  huff = 0; // starting code
  sym = 0; // starting code symbol
  len = min; // starting code length
  next = *table; // current table to fill in
  curr = root; // current table index bits
  drop = 0; // current bits to drop from code for index
  low = cast(uint)(-1); // trigger new sub-table when len > root
  used = 1U<<root; // use root table entries
  mask = used-1; // mask for comparing low

  // check available table space
  if ((type == LENS && used >= ENOUGH_LENS) || (type == DISTS && used >= ENOUGH_DISTS)) return 1;

  // process all codes and make table entries
  for (;;) {
    // create table entry
    this_.bits = cast(ubyte)(len-drop);
    if (cast(int)(work[sym]) < end) {
      this_.op = cast(ubyte)0;
      this_.val = work[sym];
    } else if (cast(int)(work[sym]) > end) {
      this_.op = cast(ubyte)(extra[work[sym]]);
      this_.val = base[work[sym]];
    } else {
      this_.op = cast(ubyte)(32+64); // end of block
      this_.val = 0;
    }

    // replicate for those indices with low len bits equal to huff
    incr = 1U<<(len-drop);
    fill = 1U<<curr;
    do {
      fill -= incr;
      next[(huff>>drop)+fill] = this_;
    } while (fill != 0);

    // backwards increment the len-bit code huff
    incr = 1U<<(len-1);
    while (huff&incr) incr >>= 1;
    if (incr != 0) {
      huff &= incr-1;
      huff += incr;
    } else {
      huff = 0;
    }

    // go to next symbol, update count, len
    sym++;
    if (--(count[len]) == 0) {
      if (len == max) break;
      len = lens[work[sym]];
    }

    // create new sub-table if needed
    if (len > root && (huff&mask) != low) {
      // if first time, transition to sub-tables
      if (drop == 0) drop = root;

      // increment past last table
      next += 1U<<curr;

      // determine length of next table
      curr = len-drop;
      left = cast(int)(1<<curr);
      while (curr+drop < max) {
        left -= count[curr+drop];
        if (left <= 0) break;
        curr++;
        left <<= 1;
      }

      // check for enough space
      used += 1U<<curr;
      if ((type == LENS && used >= ENOUGH_LENS) || (type == DISTS && used >= ENOUGH_DISTS)) return 1;

      // point entry in root table to sub-table
      low = huff&mask;
      (*table)[low].op = cast(ubyte)curr;
      (*table)[low].bits = cast(ubyte)root;
      (*table)[low].val = cast(ushort)(next-*table);
    }
  }

  /*
     Fill in rest of table for incomplete codes.  This loop is similar to the
     loop above in incrementing huff for table indices.  It is assumed that
     len is equal to curr+drop, so there is no loop needed to increment
     through high index bits.  When the current sub-table is filled, the loop
     drops back to the root table to fill in any remaining entries there.
   */
  this_.op = cast(ubyte)64; // invalid code marker
  this_.bits = cast(ubyte)(len-drop);
  this_.val = cast(ushort)0;
  while (huff != 0) {
    // when done with sub-table, drop back to root table
    if (drop != 0 && (huff&mask) != low) {
      drop = 0;
      len = root;
      next = *table;
      curr = root;
      this_.bits = cast(ubyte)len;
    }

    // put invalid code marker in table
    next[huff>>drop] = this_;

    // backwards increment the len-bit code huff
    incr = 1U<<(len-1);
    while (huff&incr) incr >>= 1;
    if (incr != 0) {
      huff &= incr-1;
      huff += incr;
    } else {
      huff = 0;
    }
  }

  // set return parameters
  *table += used;
  *bits = root;
  return 0;
}


enum WSIZE = 65536U;

/* Get a byte of input into the bit accumulator, or return from inflateBack()
   with an error if there is no input available. */
enum PULLBYTE = q{
  do {
    /*PULL*/
    if (have == 0) {
      have = in_(&next);
      if (have == 0) {
        next = null;
        ret = Z_BUF_ERROR;
        goto inf_leave;
      }
    }
    /* */
    have--;
    hold += cast(uint)(*next++)<<bits;
    bits += 8;
  } while (false);
};

/* Assure that there are at least n bits in the bit accumulator.  If there is
   not enough available input to do that, then return from inflateBack() with
   an error. */
enum NEEDBITS(string n) = "do { while (bits < cast(uint)("~n~")) { "~PULLBYTE~" } } while (false);";

// Return the low n bits of the bit accumulator (n <= 16)
enum BITS(string n) = "(cast(uint)hold&((1U<<("~n~"))-1))";

// Remove n bits from the bit accumulator
enum DROPBITS(string n) = "do { hold >>= ("~n~"); bits -= cast(uint)("~n~"); } while (false);";

// Remove zero to seven bits as needed to go to a byte boundary
enum BYTEBITS = q{
  do {
    hold >>= bits&7;
    bits -= bits&7;
  } while (false);
};

/* Assure that some output space is available, by writing out the window
   if it's full.  If the write fails, return from inflateBack() with a
   Z_BUF_ERROR. */
enum ROOM = q{
  do {
    if (left == 0) {
      put = window;
      left = WSIZE;
      wrap = 1;
      if (out_(put, cast(uint)left)) {
        ret = Z_BUF_ERROR;
        goto inf_leave;
      }
    }
  } while (false);
};

/*
   strm provides the memory allocation functions and window buffer on input,
   and provides information on the unused input on return.  For Z_DATA_ERROR
   returns, strm will also provide an error message.

   in_() and out_() are the call-back input and output functions.  When
   inflateBack() needs more input, it calls in_().  When inflateBack() has
   filled the window with output, or when it completes with data in the
   window, it calls out_() to write out the data.  The application must not
   change the provided input until in_() is called again or inflateBack()
   returns.  The application must not change the window/output buffer until
   inflateBack() returns.

   in_() and out_() are called with a descriptor parameter provided in the
   inflateBack() call.  This parameter can be a structure that provides the
   information required to do the read or write, as well as accumulated
   information on the input and output such as totals and check values.

   in_() should return zero on failure.  out_() should return non-zero on
   failure.  If either in_() or out_() fails, than inflateBack() returns a
   Z_BUF_ERROR.  strm.next_in can be checked for Z_NULL to see whether it
   was in_() or out_() that caused in the error.  Otherwise,  inflateBack()
   returns Z_STREAM_END on success, Z_DATA_ERROR for an deflate format
   error, or Z_MEM_ERROR if it could not allocate memory for the state.
   inflateBack() can also return Z_STREAM_ERROR if the input parameters
   are not correct, i.e. strm is Z_NULL or the state was not initialized.
 */
int inflateBack9 (zd64_stream* strm, scope uint delegate (ubyte**) in_, scope int delegate (const(ubyte)*, uint) out_) {
  inflate_state* state;

  // Check that the strm exists and that the state was initialized
  if (strm is null || strm.state is null) return Z_STREAM_ERROR;
  state = cast(inflate_state*)strm.state;

  with (state) {
    // Inflate until end of block marked as last
    switch (mode) {
      case TYPE:
        // determine and dispatch block type
        if (lastblock) {
          mixin(BYTEBITS);
          mode = DONE;
          break;
        }
        mixin(NEEDBITS!"3");
        lastblock = mixin(BITS!"1");
        mixin(DROPBITS!"1");
        switch (mixin(BITS!"2")) {
          case 0: // stored block
            mode = STORED;
            break;
          case 1: // fixed block
            lencode = lenfix.ptr;
            lenbits = 9;
            distcode = distfix.ptr;
            distbits = 5;
            mode = LEN; // decode codes
            break;
          case 2: // dynamic block
            mode = TABLE;
            break;
          case 3:
            //strm.msg = "invalid block type";
            mode = BAD;
            break;
          default: assert(0, "wtf?!");
        }
        mixin(DROPBITS!"2");
        break;

      case STORED:
        // get and verify stored block length
        mixin(BYTEBITS); // go to byte boundary
        mixin(NEEDBITS!"32");
        if ((hold&0xffff) != ((hold>>16)^0xffff)) {
          //strm.msg = "invalid stored block lengths";
          mode = BAD;
          break;
        }
        length = cast(uint)hold&0xffff;
        // Clear the input bit accumulator
        hold = 0;
        bits = 0;

        // copy stored block from input to output
        while (length != 0) {
          copy = length;
          //PULL();
          if (have == 0) {
            have = in_(&next);
            if (have == 0) {
              next = null;
              ret = Z_BUF_ERROR;
              goto inf_leave;
            }
          }
          //
          mixin(ROOM);
          if (copy > have) copy = have;
          if (copy > left) copy = left;
          { import core.stdc.string : memcpy; memcpy(put, next, copy); }
          //zmemcpy(put, next, copy);
          have -= copy;
          next += copy;
          left -= copy;
          put += copy;
          length -= copy;
        }
        mode = TYPE;
        break;

      case TABLE:
        // get dynamic table entries descriptor
        mixin(NEEDBITS!"14");
        state.nlen = mixin(BITS!"5")+257;
        mixin(DROPBITS!"5");
        state.ndist = mixin(BITS!"5")+1;
        mixin(DROPBITS!"5");
        state.ncode = mixin(BITS!"4")+4;
        mixin(DROPBITS!"4");
        if (state.nlen > 286) {
          //strm.msg = "too many length symbols";
          mode = BAD;
          break;
        }

        // get code length code lengths (not a typo)
        state.have_ = 0;
        while (state.have_ < state.ncode) {
          mixin(NEEDBITS!"3");
          state.lens[order[state.have_++]] = cast(ushort)mixin(BITS!"3");
          mixin(DROPBITS!"3");
        }
        while (state.have_ < 19) state.lens[order[state.have_++]] = 0;
        state.next_ = state.codes.ptr;
        lencode = cast(const(code)*)(state.next_);
        lenbits = 7;
        ret = inflate_table9(CODES, state.lens.ptr, 19, &(state.next_), &(lenbits), state.work.ptr);
        if (ret) {
          //strm.msg = "invalid code lengths set";
          mode = BAD;
          break;
        }

        // get length and distance code code lengths
        state.have_ = 0;
        while (state.have_ < state.nlen+state.ndist) {
          for (;;) {
            here = lencode[mixin(BITS!"lenbits")];
            if (cast(uint)(here.bits) <= bits) break;
            mixin(PULLBYTE);
          }
          if (here.val < 16) {
            mixin(NEEDBITS!"here.bits");
            mixin(DROPBITS!"here.bits");
            state.lens[state.have_++] = here.val;
          } else {
            if (here.val == 16) {
              mixin(NEEDBITS!"here.bits+2");
              mixin(DROPBITS!"here.bits");
              if (state.have_ == 0) {
                //strm.msg = "invalid bit length repeat";
                mode = BAD;
                break;
              }
              len = cast(uint)(state.lens[state.have_-1]);
              copy = 3+mixin(BITS!"2");
              mixin(DROPBITS!"2");
            } else if (here.val == 17) {
              mixin(NEEDBITS!"here.bits+3");
              mixin(DROPBITS!"here.bits");
              len = 0;
              copy = 3+mixin(BITS!"3");
              mixin(DROPBITS!"3");
            } else {
              mixin(NEEDBITS!"here.bits+7");
              mixin(DROPBITS!"here.bits");
              len = 0;
              copy = 11+mixin(BITS!"7");
              mixin(DROPBITS!"7");
            }
            if (state.have_+copy > state.nlen+state.ndist) {
              //strm.msg = "invalid bit length repeat";
              mode = BAD;
              break;
            }
            while (copy--) state.lens[state.have_++] = cast(ushort)len;
          }
        }

        // handle error breaks in while
        if (mode == BAD) break;

        // check for end-of-block code (better have one)
        if (state.lens[256] == 0) {
          //strm.msg = "invalid code -- missing end-of-block";
          mode = BAD;
          break;
        }

        /* build code tables -- note: do not change the lenbits or distbits
           values here (9 and 6) without reading the comments in inftree9.h
           concerning the ENOUGH constants, which depend on those values */
        state.next_ = state.codes.ptr;
        lencode = cast(const(code)*)(state.next_);
        lenbits = 9;
        ret = inflate_table9(LENS, state.lens.ptr, state.nlen, &(state.next_), &(lenbits), state.work.ptr);
        if (ret) {
          //strm.msg = "invalid literal/lengths set";
          mode = BAD;
          break;
        }
        distcode = cast(const(code)*)(state.next_);
        distbits = 6;
        ret = inflate_table9(DISTS, state.lens.ptr+state.nlen, state.ndist, &(state.next_), &(distbits), state.work.ptr);
        if (ret) {
          //strm.msg = "invalid distances set";
          mode = BAD;
          break;
        }
        mode = LEN;
        goto case;

      case LEN:
        // get a literal, length, or end-of-block code
        for (;;) {
          here = lencode[mixin(BITS!"lenbits")];
          if (cast(uint)(here.bits) <= bits) break;
          mixin(PULLBYTE);
        }
        if (here.op && (here.op&0xf0) == 0) {
          last = here;
          for (;;) {
            here = lencode[last.val+(mixin(BITS!"last.bits+last.op")>>last.bits)];
            if (cast(uint)(last.bits+here.bits) <= bits) break;
            mixin(PULLBYTE);
          }
          mixin(DROPBITS!"last.bits");
        }
        mixin(DROPBITS!"here.bits");
        length = cast(uint)here.val;

        // process literal
        if (here.op == 0) {
          mixin(ROOM);
          *put++ = cast(ubyte)(length);
          left--;
          mode = LEN;
          break;
        }

        // process end of block
        if (here.op&32) {
          mode = TYPE;
          break;
        }

        // invalid code
        if (here.op&64) {
          //strm.msg = "invalid literal/length code";
          mode = BAD;
          break;
        }

        // length code -- get extra bits, if any
        extra = cast(uint)(here.op)&31;
        if (extra != 0) {
          mixin(NEEDBITS!"extra");
          length += mixin(BITS!"extra");
          mixin(DROPBITS!"extra");
        }

        // get distance code
        for (;;) {
          here = distcode[mixin(BITS!"distbits")];
          if (cast(uint)(here.bits) <= bits) break;
          mixin(PULLBYTE);
        }
        if ((here.op&0xf0) == 0) {
          last = here;
          for (;;) {
            here = distcode[last.val+(mixin(BITS!"last.bits+last.op")>>last.bits)];
            if (cast(uint)(last.bits+here.bits) <= bits) break;
            mixin(PULLBYTE);
          }
          mixin(DROPBITS!"last.bits");
        }
        mixin(DROPBITS!"here.bits");
        if (here.op&64) {
          //strm.msg = "invalid distance code";
          mode = BAD;
          break;
        }
        offset = cast(uint)here.val;

        // get distance extra bits, if any
        extra = cast(uint)(here.op)&15;
        if (extra != 0) {
          mixin(NEEDBITS!"extra");
          offset += mixin(BITS!"extra");
          mixin(DROPBITS!"extra");
        }
        if (offset > WSIZE-(wrap ? 0: left)) {
          //strm.msg = "invalid distance too far back";
          mode = BAD;
          break;
        }

        // copy match from window to output
        do {
            mixin(ROOM);
          copy = WSIZE-offset;
          if (copy < left) {
            from = put+copy;
            copy = left-copy;
          } else {
            from = put-offset;
            copy = left;
          }
          if (copy > length) copy = length;
          length -= copy;
          left -= copy;
          do { *put++ = *from++; } while (--copy);
        } while (length != 0);
        break;

      case DONE:
        // inflate stream terminated properly -- write leftover output
        ret = Z_STREAM_END;
        if (left < WSIZE) {
          if (out_(window, cast(uint)(WSIZE-left))) ret = Z_BUF_ERROR;
        }
        goto inf_leave;

      case BAD:
        ret = Z_DATA_ERROR;
        goto inf_leave;

      default: // can't happen, but makes compilers happy
        ret = Z_STREAM_ERROR;
        goto inf_leave;
    }

    // Return unused input
  inf_leave:
    strm.next_in = next;
    strm.avail_in = have;
  }

  return state.ret;
}


int inflateBack9Reset (zd64_stream* strm) {
  import core.stdc.string : memset;
  if (strm is null || strm.state is null) return Z_STREAM_ERROR;
  //strm.msg = null; // in case we return an error
  inflate_state* state = cast(inflate_state*)strm.state;
  memset(state, 0, inflate_state.sizeof);
  state.window_[] = 0; // just in case
  with (state) {
    // Reset the state
    //strm.msg = null;
    mode = TYPE;
    lastblock = 0;
    wrap = 0;
    window = state.window_.ptr;
    next = strm.next_in;
    have = (next !is null ? strm.avail_in : 0);
    hold = 0;
    bits = 0;
    put = window;
    left = WSIZE;
    lencode = null;
    distcode = null;
  }
  return Z_OK;
}


/*
   strm provides memory allocation functions in zalloc and zfree, or
   Z_NULL to use the library memory allocation functions.

   window is a user-supplied window and output buffer that is 64K bytes.
 */
int inflateBack9Init (zd64_stream* strm) {
  import core.stdc.stdlib : malloc;
  inflate_state *state;

  if (strm is null) return Z_STREAM_ERROR;
  //strm.msg = null; // in case we return an error
  state = cast(inflate_state*)malloc(inflate_state.sizeof);
  if (state is null) { /*strm.msg = "out of memory";*/ return Z_MEM_ERROR; }
  strm.state = cast(void*)state;

  return inflateBack9Reset(strm);
}


void inflateBack9End (zd64_stream* strm) {
  import core.stdc.stdlib : free;
  if (strm is null) return;
  if (strm.state !is null) { free(strm.state); strm.state = null; }
}


// ////////////////////////////////////////////////////////////////////////// //
struct Inflater64 {
  public enum InitUpkBufSize = WSIZE; // way too much

  zd64_stream zs;
  BitReader br;

public:
  void close () { inflateBack9End(&zs); br.close(); }

  void setup (VFile fl, ulong agflags, long apos, uint apksize, uint aupksize) {
    if (inflateBack9Init(&zs) != Z_OK) throw new VFSException("can't init inflate9");
    br.setup(fl, apos, apksize, aupksize);
    reset();
  }

  void reset () {
    inflateBack9Reset(&zs);
    br.reset();
    if (br.upktotalsize == 0) return;
    zs.next_in = null;
    zs.avail_in = 0;
  }

  bool unpackChunk (scope VStreamDecoderLowLevelROPutBytesDg putUB) {
    if (br.upkleft == 0) return false; // packed file EOF
    auto res = inflateBack9(&zs,
      (ubyte** ibp) {
        auto rd = br.readNewBuffer();
        *ibp = br.inbuf.ptr;
        return rd;
      },
      (const(ubyte)* buf, uint len) {
        if (len == 0) return 0; // just in case
        putUB(buf[0..len]);
        return 0;
      },
    );
    if (res != Z_OK) {
      if (res == Z_STREAM_END) return false;
      throw new Exception("inflate9 packed data corrupted");
    }
    return true;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
private:
// LZMA Reference Decoder
// 2015-06-14 : Igor Pavlov : Public domain

// This code implements LZMA file decoding according to LZMA specification.
// This code is not optimized for speed.
struct CLzmaDecoder {
public:
  enum Result {
    Error = -1,
    Continue = 0,
    FinishedWithMarker = 1,
    FinishedWithoutMarker = 2,
  }

private:
  CProb[kNumStates<<kNumPosBitsMax] isMatch;
  CProb[kNumStates] isRep;
  CProb[kNumStates] isRepG0;
  CProb[kNumStates] isRepG1;
  CProb[kNumStates] isRepG2;
  CProb[kNumStates<<kNumPosBitsMax] isRep0Long;

  CLenDecoder lenDecoder;
  CLenDecoder repLenDecoder;

  //CProb* litProbs;
  mixin VFSHiddenPointerHelper!(CProb, "litProbs");
  usize litProbsAllotedBytes;
  CBitTreeDecoder!6[kNumLenToPosStates] posSlotDecoder;
  CBitTreeDecoder!kNumAlignBits alignDecoder;
  CProb[1+kNumFullDistances-kEndPosModelIndex] posDecoders;

  uint rep0, rep1, rep2, rep3;
  uint state;
  bool unpackSizeDefined;
  ulong unpackSize;

public:
  CRangeDecoder rangeDec;
  COutWindow outWindow;

  bool markerIsMandatory;
  uint lc, pb, lp;
  uint dictSize;
  uint dictSizeInProperties;
  bool inited;

  //@disable this (this);

  void close () {
    import core.stdc.stdlib : free;
    if (litProbs !is null) free(litProbs);
    litProbs = null;
    inited = false;
    outWindow.close();
  }

  void decodeProperties (const(ubyte)* properties) {
    enum LZMAMinDictSize = 1U<<12;
    uint d = properties[0];
    if (d >= 9*5*5) throw new Exception("Incorrect LZMA properties");
    lc = d%9;
    d /= 9;
    pb = d/5;
    lp = d%5;
    dictSizeInProperties = 0;
    for (int i = 0; i < 4; ++i) dictSizeInProperties |= cast(uint)properties[i+1]<<(8*i);
    dictSize = dictSizeInProperties;
    if (dictSize < LZMAMinDictSize) dictSize = LZMAMinDictSize;
  }

  void create (ulong aunpackSize) {
    inited = false;
    unpackSizeDefined = true;
    unpackSize = aunpackSize;
  }

  void create () {
    inited = false;
    unpackSizeDefined = false;
    unpackSize = 0;
  }


  Result decodeStep (scope ubyte delegate () readByte, scope void delegate (ubyte b) writeByte) {
    void decodeLiteral (uint state, uint rep0) {
      uint prevByte = 0;
      if (!outWindow.isEmpty()) prevByte = outWindow.getByte(1);

      uint symbol = 1;
      uint litState = ((outWindow.totalPos&((1<<lp)-1))<<lc)+(prevByte>>(8-lc));
      CProb* probs = litProbs+(0x300U*litState);

      if (state >= 7) {
        uint matchByte = outWindow.getByte(rep0+1);
        do {
          uint matchBit = (matchByte>>7)&1;
          matchByte <<= 1;
          uint bit = rangeDec.decodeBit(&probs[((1+matchBit)<<8)+symbol], readByte);
          symbol = (symbol<<1)|bit;
          if (matchBit != bit) break;
        } while (symbol < 0x100);
      } while (symbol < 0x100)
      symbol = (symbol<<1)|rangeDec.decodeBit(&probs[symbol], readByte);
      outWindow.putByte(cast(ubyte)(symbol-0x100), writeByte);
    }

    uint decodeDistance (uint len) {
      uint lenState = len;
      if (lenState > kNumLenToPosStates-1) lenState = kNumLenToPosStates-1;

      uint posSlot = posSlotDecoder[lenState].decode(rangeDec, readByte);
      if (posSlot < 4) return posSlot;

      uint numDirectBits = cast(uint)((posSlot>>1)-1);
      uint dist = ((2|(posSlot&1))<<numDirectBits);
      if (posSlot < kEndPosModelIndex) {
        dist += bitTreeReverseDecode(posDecoders.ptr+dist-posSlot, numDirectBits, rangeDec, readByte);
      } else {
        dist += rangeDec.decodeDirectBits(numDirectBits-kNumAlignBits, readByte)<<kNumAlignBits;
        dist += alignDecoder.reverseDecode(rangeDec, readByte);
      }
      return dist;
    }

    if (!inited) {
      inited = true;
      outWindow.create(dictSize);
      createLiterals();
      if (!rangeDec.initialize(readByte)) throw new Exception("can't initialize lzma range decoder");
      initialize();
      rep0 = rep1 = rep2 = rep3 = 0;
      state = 0;
    }

    if (unpackSizeDefined && unpackSize == 0 && !markerIsMandatory) {
      if (rangeDec.isFinishedOK()) return Result.FinishedWithoutMarker;
    }

    uint posState = outWindow.totalPos&((1<<pb)-1);

    if (rangeDec.decodeBit(&isMatch[(state<<kNumPosBitsMax)+posState], readByte) == 0) {
      if (unpackSizeDefined && unpackSize == 0) return Result.Error;
      decodeLiteral(state, rep0);
      state = updateStateLiteral(state);
      --unpackSize;
      return Result.Continue;
    }

    uint len;

    if (rangeDec.decodeBit(&isRep[state], readByte) != 0) {
      if (unpackSizeDefined && unpackSize == 0) return Result.Error;
      if (outWindow.isEmpty()) return Result.Error;
      if (rangeDec.decodeBit(&isRepG0[state], readByte) == 0) {
        if (rangeDec.decodeBit(&isRep0Long[(state<<kNumPosBitsMax)+posState], readByte) == 0) {
          state = updateStateShortRep(state);
          outWindow.putByte(outWindow.getByte(rep0+1), writeByte);
          --unpackSize;
          return Result.Continue;
        }
      } else {
        uint dist;
        if (rangeDec.decodeBit(&isRepG1[state], readByte) == 0) {
          dist = rep1;
        } else {
          if (rangeDec.decodeBit(&isRepG2[state], readByte) == 0) {
            dist = rep2;
          } else {
            dist = rep3;
            rep3 = rep2;
          }
          rep2 = rep1;
        }
        rep1 = rep0;
        rep0 = dist;
      }
      len = repLenDecoder.decode(rangeDec, posState, readByte);
      state = updateStateRep(state);
    } else {
      rep3 = rep2;
      rep2 = rep1;
      rep1 = rep0;
      len = lenDecoder.decode(rangeDec, posState, readByte);
      state = updateStateMatch(state);
      rep0 = decodeDistance(len);
      if (rep0 == 0xFFFFFFFF) return (rangeDec.isFinishedOK() ? Result.FinishedWithMarker : Result.Error);
      if (unpackSizeDefined && unpackSize == 0) return Result.Error;
      if (rep0 >= dictSize || !outWindow.checkDistance(rep0)) return Result.Error;
    }
    len += kMatchMinLen;
    bool isError = false;
    if (unpackSizeDefined && unpackSize < len) {
      len = cast(uint)unpackSize;
      isError = true;
    }
    outWindow.copyMatch(rep0+1, len, writeByte);
    unpackSize -= len;
    if (isError) return Result.Error;
    return Result.Continue;
  }

private:
  void createLiterals () {
    //litProbs = new CProb[](0x300U<<(lc+lp));
    import core.stdc.stdlib : realloc;
    //import core.stdc.string : memset;
    usize toalloc = (0x300U<<(lc+lp))*CProb.sizeof;
    if (litProbs is null || toalloc > litProbsAllotedBytes) {
      auto nb = cast(CProb*)realloc(litProbs, toalloc);
      if (nb is null) throw new Exception("LZMA: out of memory");
      litProbsAllotedBytes = toalloc;
      litProbs = nb;
    }
    //memset(litProbs, 0, (0x300U<<(lc+lp))*CProb.sizeof);
  }

  void initLiterals () {
    uint num = 0x300U<<(lc+lp);
    //for (uint i = 0; i < num; ++i) litProbs[i] = ProbInitValue;
    litProbs[0..num] = ProbInitValue;
  }

  void initDist () {
    for (uint i = 0; i < kNumLenToPosStates; i++) posSlotDecoder[i].initialize();
    alignDecoder.initialize();
    posDecoders[] = ProbInitValue;
  }

  void initialize () {
    initLiterals();
    initDist();

    isMatch[] = ProbInitValue;
    isRep[] = ProbInitValue;
    isRepG0[] = ProbInitValue;
    isRepG1[] = ProbInitValue;
    isRepG2[] = ProbInitValue;
    isRep0Long[] = ProbInitValue;

    lenDecoder.initialize();
    repLenDecoder.initialize();
  }

static:
  struct COutWindow {
  private:
    //ubyte* buf;
    mixin VFSHiddenPointerHelper!(ubyte, "buf");
    uint pos;
    uint size;
    uint bufsize;
    bool isFull;

  public:
    uint totalPos;

    //@disable this (this);

    void close () {
      import core.stdc.stdlib : free;
      if (buf !is null) {
        //{ import core.stdc.stdio : printf; printf("LZMA: freeing: buf=%p; bufsize=%u\n", buf, bufsize); }
        free(buf);
        buf = null;
      }
    }

    void create (uint dictSize) @trusted {
      import core.stdc.stdlib : realloc;
      if (buf is null || bufsize < dictSize) {
        auto nb = cast(ubyte*)realloc(buf, dictSize);
        if (nb is null) {
          //{ import core.stdc.stdio : printf; printf("*** buf=%p; nb=%p; bufsize=%u; dictSize=%u\n", buf, nb, bufsize, dictSize); }
          throw new Exception("LZMA: cannot allocate sliding window");
        }
        buf = nb;
        bufsize = dictSize;
      }
      size = dictSize;
      reset();
    }

    void reset () {
      pos = 0;
      isFull = false;
      totalPos = 0;
      buf[0..size] = 0; // just in case
    }

    ubyte getByte (uint dist) const pure nothrow @trusted @nogc { pragma(inline, true); return (buf[dist <= pos ? pos-dist : size-dist+pos]); }

    void putByte (ubyte b, scope void delegate (ubyte b) writeByte) {
      ++totalPos;
      buf[pos++] = b;
      if (pos == size) { pos = 0; isFull = true; }
      writeByte(b);
    }

    void copyMatch (uint dist, uint len, scope void delegate (ubyte b) writeByte) {
      pragma(inline, true);
      while (len--) {
        //putByte(getByte(dist));
        ubyte b = getByte(dist);
        ++totalPos;
        buf[pos++] = b;
        if (pos == size) { pos = 0; isFull = true; }
        writeByte(b);
      }
    }

    bool checkDistance (uint dist) const pure nothrow @trusted @nogc { pragma(inline, true); return (dist <= pos || isFull); }

    bool isEmpty () const pure nothrow @trusted @nogc { pragma(inline, true); return (pos == 0 && !isFull); }
  }


  enum kNumBitModelTotalBits = 11;
  enum kNumMoveBits = 5;

  alias CProb = ushort;

  enum ProbInitValue = (1U<<kNumBitModelTotalBits)/2;


  struct CRangeDecoder {
  private:
    enum kTopValue = 1U<<24;

    uint range;
    uint code;

  private:
    void normalize (scope ubyte delegate () readByte) {
      if (range < kTopValue) {
        range <<= 8;
        code = (code<<8)|readByte();
      }
    }

  public:
    bool corrupted;

    //@disable this (this);

    bool initialize (scope ubyte delegate () readByte) {
      corrupted = false;
      range = 0xFFFFFFFFU;
      code = 0;
      ubyte b = readByte();
      for (int i = 0; i < 4; i++) code = (code<<8)|readByte();
      if (b != 0 || code == range) corrupted = true;
      return (b == 0);
    }

    bool isFinishedOK () const pure nothrow @safe @nogc { pragma(inline, true); return (code == 0); }

    uint decodeDirectBits (uint numBits, scope ubyte delegate () readByte) {
      uint res = 0;
      do {
        range >>= 1;
        code -= range;
        uint t = 0U-(cast(uint)code>>31);
        code += range&t;
        if (code == range) corrupted = true;
        normalize(readByte);
        res <<= 1;
        res += t+1;
      } while (--numBits);
      return res;
    }

    uint decodeBit (CProb* prob, scope ubyte delegate () readByte) {
      uint v = *prob;
      uint bound = (range>>kNumBitModelTotalBits)*v;
      uint symbol;
      if (code < bound) {
        v += ((1<<kNumBitModelTotalBits)-v)>>kNumMoveBits;
        range = bound;
        symbol = 0;
      } else {
        v -= v>>kNumMoveBits;
        code -= bound;
        range -= bound;
        symbol = 1;
      }
      *prob = cast(CProb)v;
      normalize(readByte);
      return symbol;
    }
  }


  uint bitTreeReverseDecode (CProb* probs, uint numBits, ref CRangeDecoder rc, scope ubyte delegate () readByte) {
    uint m = 1;
    uint symbol = 0;
    for (uint i = 0; i < numBits; ++i) {
      uint bit = rc.decodeBit(probs+m, readByte);
      m <<= 1;
      m += bit;
      symbol |= bit<<i;
    }
    return symbol;
  }


  struct CBitTreeDecoder(uint NumBits) {
    CProb[1U<<NumBits] probs = ProbInitValue;

  public:
    //@disable this (this);

    void initialize () { probs[] = ProbInitValue; }

    uint decode (ref CRangeDecoder rc, scope ubyte delegate () readByte) {
      uint m = 1;
      for (uint i = 0; i < NumBits; ++i) m = (m<<1)+rc.decodeBit(&probs[m], readByte);
      return m-(1U<<NumBits);
    }

    uint reverseDecode (ref CRangeDecoder rc, scope ubyte delegate () readByte) { pragma(inline, true); return bitTreeReverseDecode(probs.ptr, NumBits, rc, readByte); }
  }


  enum kNumPosBitsMax = 4;

  enum kNumStates = 12;
  enum kNumLenToPosStates = 4;
  enum kNumAlignBits = 4;
  enum kStartPosModelIndex = 4;
  enum kEndPosModelIndex = 14;
  enum kNumFullDistances = 1U<<(kEndPosModelIndex>>1);
  enum kMatchMinLen = 2;


  struct CLenDecoder {
    CProb choice;
    CProb choice2;
    CBitTreeDecoder!3[1U<<kNumPosBitsMax] lowCoder;
    CBitTreeDecoder!3[1U<<kNumPosBitsMax] midCoder;
    CBitTreeDecoder!8 highCoder;

  public:
    //@disable this (this);

    void initialize () {
      choice = ProbInitValue;
      choice2 = ProbInitValue;
      highCoder.initialize();
      for (uint i = 0; i < (1<<kNumPosBitsMax); ++i) {
        lowCoder[i].initialize();
        midCoder[i].initialize();
      }
    }

    uint decode (ref CRangeDecoder rc, uint posState, scope ubyte delegate () readByte) {
      if (rc.decodeBit(&choice, readByte) == 0) return lowCoder[posState].decode(rc, readByte);
      if (rc.decodeBit(&choice2, readByte) == 0) return 8+midCoder[posState].decode(rc, readByte);
      return 16+highCoder.decode(rc, readByte);
    }
  }


  uint updateStateLiteral (uint state) pure nothrow @safe @nogc {
    pragma(inline, true);
    /*
    if (state < 4) return 0;
    if (state < 10) return state-3;
    return state-6;
    */
    return (state < 4 ? 0 : state < 10 ? state-3 : state-6);
  }
  uint updateStateMatch (uint state) pure nothrow @safe @nogc { pragma(inline, true); return (state < 7 ? 7 : 10); }
  uint updateStateRep (uint state) pure nothrow @safe @nogc { pragma(inline, true); return (state < 7 ? 8 : 11); }
  uint updateStateShortRep (uint state) pure nothrow @safe @nogc { pragma(inline, true); return (state < 7 ? 9 : 11); }
}


// ////////////////////////////////////////////////////////////////////////// //
struct Unlzmaer {
  public enum InitUpkBufSize = 0; // dynamic

  CLzmaDecoder lzmaDecoder;
  BitReader br;
  bool inited;

public:
  void close () {
    lzmaDecoder.close();
    br.close();
  }

  void setup (VFile fl, ulong agflags, long apos, uint apksize, uint aupksize) {
    br.setup(fl, apos, apksize, aupksize);
    version(ziparc_debug) debug(ziparc) { import core.stdc.stdio : printf; printf("::: LZMA this=0x%08x\n", &this); }
    reset();
  }

  void reset () {
    br.reset();
    if (br.upktotalsize == 0) return;
    inited = false;
  }

  bool unpackChunk (scope VStreamDecoderLowLevelROPutBytesDg putUB) {
    if (br.upkleft == 0) return false; // packed file EOF
    if (!inited) {
      inited = true;
      ubyte[4] ziplzmahdr;
      foreach (ref ubyte b; ziplzmahdr[]) b = br.readPackedByte!ubyte;
      if (ziplzmahdr[3] != 0) throw new Exception("LZMA: invalid header");
      //{ import core.stdc.stdio : printf; printf("LZMA version: %u.%u\nprops size: %u\n", ziplzmahdr[0], ziplzmahdr[1], ziplzmahdr[2]); }
      if (ziplzmahdr[2] == 0 || ziplzmahdr[2] < 5) throw new Exception("LZMA: invalid header size");
      ubyte[5] header = 0;
      foreach (ref ubyte b; header[0..5]) b = br.readPackedByte!ubyte;
      foreach (immutable _; 5..ziplzmahdr[2]) br.readPackedByte!ubyte; // skip other bytes
      lzmaDecoder.decodeProperties(header.ptr);
      lzmaDecoder.markerIsMandatory = false;
      lzmaDecoder.create(br.upktotalsize);
    }
    auto res = lzmaDecoder.decodeStep(
      delegate () => br.readPackedByte!ubyte,
      (ubyte b) => putUB(b),
    );
    switch (res) {
      case CLzmaDecoder.Result.Continue: return true;
      case CLzmaDecoder.Result.Error: throw new VFSException("LZMA stream corrupted");
      case CLzmaDecoder.Result.FinishedWithMarker:
      case CLzmaDecoder.Result.FinishedWithoutMarker:
        br.upkleft = 0; //HACK!
        return false;
      default: assert(0, "LZMA internal error");
    }
    return true;
  }
}
