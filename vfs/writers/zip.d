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
module iv.vfs.writers.zip /*is aliced*/;
private:

public enum VFSZipWriterSupportsLZMA = true;
pragma(lib, "lzma");
import etc.c.lzma;

import iv.alice;
import iv.utfutil;
import iv.vfs;


// ////////////////////////////////////////////////////////////////////////// //
public struct ZipFileInfo {
  enum DefaultMode {
    File = 0b110_100_100,
    Dir = 0b111_101_101,
  }
  string name;
  ulong pkofs; // offset of file header
  ulong size;
  ulong pksize;
  uint crc; // crc32(0, null, 0);
  ushort method;
  ZipFileTime time;
  ushort unixmode = 0b110_100_100; // default one
  bool dir;

  @property string methodName () const pure nothrow @safe @nogc {
    switch (method) {
      case 0: return "store";
      case 8: return "deflate";
      case 14: return "lzma";
      default:
    }
    return "unknown";
  }
}


// ////////////////////////////////////////////////////////////////////////// //
public struct ZipFileTime {
  ushort mtime; // last mod file time
  ushort mdate; // last mod file date

  // create from unixtime
  this() (ulong unixtime/*, bool utc=true*/) nothrow @trusted @nogc {
    /*
    import std.datetime;
    SysTime tm = (utc ? SysTime.fromUnixTime(unixtime, UTC()) : SysTime.fromUnixTime(unixtime));
    //TODO: validity checks
    //{ import core.stdc.stdio : printf; printf("year=%u; month=%u; day=%u; hour=%u; min=%u; day=%u\n", tm.year, tm.month, tm.day, tm.hour, tm.minute, tm.second); }
    year = tm.year;
    month = tm.month;
    day = tm.day;
    hour = tm.hour;
    min = tm.minute;
    sec = tm.second;
    */
    import core.stdc.time : tm;
    import core.sys.posix.time : localtime_r;
    int utime = (unixtime > int.max ? int.max : cast(int)unixtime);
    tm tmx;
    localtime_r(&utime, &tmx);
    year = tmx.tm_year+1900;
    month = tmx.tm_mon;
    day = tmx.tm_mday-1;
    hour = tmx.tm_hour;
    min = tmx.tm_min;
    sec = tmx.tm_sec;
  }

@property nothrow @safe @nogc:
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

pure:
  void hour (int v) { if (v < 0) v = 0; else if (v > 23) v = 23; mtime = cast(ushort)((mtime&~(0x1f<<11))|(v<<11)); }
  void min (int v) { if (v < 0) v = 0; else if (v > 59) v = 59; mtime = cast(ushort)((mtime&~(0x1f<<5))|(v<<5)); }
  void sec (int v) { if (v < 0) v = 0; else if (v > 59) v = 59; mtime = cast(ushort)((mtime&~0x3f)|v); }

  void year (int v) { if (v < 1980) v = 1980; else if (v > 2107) v = 2107; v -= 1980; mdate = cast(ushort)((mdate&~(0x7f<<9))|(v<<9)); }
  void month (int v) { if (v < 0) v = 0; else if (v > 11) v = 11; v += 1; mdate = cast(ushort)((mdate&~(0x0f<<5))|(v<<5)); }
  void day (int v) { if (v < 0) v = 0; else if (v > 30) v = 30; v += 1; mdate = cast(ushort)((mdate&~0x1f)|v); }

const:
  ubyte hour () { pragma(inline, true); return cast(ubyte)(((mtime>>11))%24); } // 0..23
  ubyte min () { pragma(inline, true); return cast(ubyte)(((mtime>>5)&0x3f)%60); } // 0..59
  ubyte sec () { pragma(inline, true); return cast(ubyte)(((mtime&0x1f)*2)%60); } // 0..59

  ushort year () { pragma(inline, true); return cast(ushort)((mdate>>9)+1980); }
  ubyte month () { pragma(inline, true); return cast(ubyte)(((mdate>>5)&0x0f ? ((mdate>>5)&0x0f)-1 : 0)%12); } // 0..11
  ubyte day () { pragma(inline, true); return cast(ubyte)((mdate&0x1f ? (mdate&0x1f)-1 : 0)%31); } // 0..30
}


// ////////////////////////////////////////////////////////////////////////// //
public class ZipWriter {
public:
  enum Method {
    Store,
    Deflate,
    Lzma,
  }

public:
  VFile fo; // do not use
  ZipFileInfo[] files; // do not modify

public:
  this (VFile afo) { fo = afo; }

  @property bool isOpen () { return fo.isOpen; }

  uint appendDir(T:const(char)[]) (T aname, in auto ref ZipFileTime ftime) {
    if (!fo.isOpen) throw new VFSException("no archive file");
    if (aname.length == 0) throw new VFSException("empty name");
    static if (is(T == string)) string fname = aname; else string fname = aname.idup;
    if (fname[$-1] != '/') fname ~= '/';
    foreach (char ch; fname) if (ch == '\\') throw new VFSException("shitdoze path delimiters not supported");
    if (files.length >= int.max) throw new VFSException("too many files");
    ZipFileInfo fi;
    fi.name = fname;
    fi.time = ftime;
    fi.unixmode = fi.DefaultMode.Dir;
    fi.dir = true;
    fi.pkofs = fo.tell;
    fo.zipWriteLocalHeader(fi);
    files ~= fi;
    return cast(uint)files.length-1;
  }

  // return index in `files` array
  uint pack(T:const(char)[]) (VFile fl, T fname, in auto ref ZipFileTime ftime, Method method=Method.Deflate, ulong oldsize=ulong.max, scope void delegate (ulong cur) onProgress=null) {
    if (!fo.isOpen) throw new VFSException("no archive file");
    if (!fl.isOpen) throw new VFSException("no source file");
    scope(failure) { files = null; fo = VFile.init; }
    if (fname.length == 0) throw new VFSException("empty name");
    if (fname[$-1] == '/') throw new VFSException("directories not supported");
    foreach (char ch; fname) if (ch == '\\') throw new VFSException("shitdoze path delimiters not supported");
    static if (is(T == string)) {
      alias pkname = fname;
    } else {
      string pkname = fname.idup;
    }
    final switch (method) {
      case Method.Store: files ~= zipOne!"store"(fo, pkname, fl, ftime, oldsize, onProgress); break;
      case Method.Deflate: files ~= zipOne!"deflate"(fo, pkname, fl, ftime, oldsize, onProgress); break;
      case Method.Lzma: files ~= zipOne!"lzma"(fo, pkname, fl, ftime, oldsize, onProgress); break;
    }
    return cast(uint)files.length-1;
  }

  uint pack(T:const(char)[]) (VFile fl, T fname, Method method=Method.Deflate, ulong oldsize=ulong.max, scope void delegate (ulong cur) onProgress=null) {
    return pack!T(fl, fname, ZipFileTime.init, method, oldsize);
  }

  void finish () {
    if (!fo.isOpen) throw new VFSException("no archive file");
    scope(exit) { files = null; fo = VFile.init; }
    zipFinish(fo, files);
  }

  void abort () {
    if (!fo.isOpen) throw new VFSException("no archive file");
    files = null;
    fo = VFile.init;
  }
}


// ////////////////////////////////////////////////////////////////////////// //
// returs crc
uint zpack (VFile ds, VFile ss, out bool aborted, scope void delegate (ulong cur) onProgress) {
  import etc.c.zlib;
  import core.stdc.stdlib;

  enum IBSize = 65536;
  enum OBSize = 65536;

  z_stream zst;
  ubyte* ib, ob;
  int err;
  uint crc;

  aborted = false;
  crc = crc32(0, null, 0);

  ib = cast(ubyte*)malloc(IBSize);
  if (ib is null) assert(0, "out of memory");
  scope(exit) free(ib);

  ob = cast(ubyte*)malloc(OBSize);
  if (ob is null) assert(0, "out of memory");
  scope(exit) free(ob);

  ulong srcsize = ss.size, outsize = 0;

  zst.next_out = ob;
  zst.avail_out = OBSize;
  zst.next_in = ib;
  zst.avail_in = 0;
  err = deflateInit2(&zst, Z_BEST_COMPRESSION, Z_DEFLATED, -15, 9, 0);
  if (err != Z_OK) throw new Exception("zlib error");
  scope(exit) deflateEnd(&zst);

  ulong bytesread = 0;

  bool eof = false;
  while (!eof) {
    if (zst.avail_in == 0) {
      // read input buffer part
      auto rd = ss.rawRead(ib[0..IBSize]);
      eof = (rd.length == 0);
      if (rd.length != 0) { crc = crc32(crc, ib, cast(uint)rd.length); }
      zst.next_in = ib;
      zst.avail_in = cast(uint)rd.length;
      bytesread += rd.length;
      if (onProgress !is null) onProgress(bytesread);
    }
    // now process the whole input
    while (zst.avail_in > 0) {
      err = deflate(&zst, Z_NO_FLUSH);
      if (err != Z_OK) throw new Exception("zlib compression error");
      if (zst.avail_out < OBSize) {
        if (outsize+(OBSize-zst.avail_out) >= srcsize) {
          // this will be overwritten anyway
          aborted = true;
          return 0;
        }
        outsize += OBSize-zst.avail_out;
        ds.rawWriteExact(ob[0..OBSize-zst.avail_out]);
        zst.next_out = ob;
        zst.avail_out = OBSize;
      }
    }
  }
  // empty write buffer (just in case)
  if (zst.avail_out < OBSize) {
    if (outsize+(OBSize-zst.avail_out) >= srcsize) {
      // this will be overwritten anyway
      aborted = true;
      return 0;
    }
    outsize += OBSize-zst.avail_out;
    ds.rawWriteExact(ob[0..OBSize-zst.avail_out]);
    zst.next_out = ob;
    zst.avail_out = OBSize;
  }
  // do leftovers
  for (;;) {
    zst.avail_in = 0;
    err = deflate(&zst, Z_FINISH);
    if (err != Z_OK && err != Z_STREAM_END) throw new Exception("zlib compression error");
    if (zst.avail_out < OBSize) {
      if (outsize+(OBSize-zst.avail_out) >= srcsize) {
        // this will be overwritten anyway
        aborted = true;
        return 0;
      }
      outsize += OBSize-zst.avail_out;
      ds.rawWriteExact(ob[0..OBSize-zst.avail_out]);
      zst.next_out = ob;
      zst.avail_out = OBSize;
    } else {
      //if (err != Z_OK) break;
      break;
    }
  }
  // succesfully flushed?
  if (err != Z_STREAM_END) throw new Exception("zlib compression error");
  return crc;
}


// ////////////////////////////////////////////////////////////////////////// //
// returs crc
static if (VFSZipWriterSupportsLZMA) uint lzmapack (VFile ds, VFile ss, out bool aborted, scope void delegate (ulong cur) onProgress) {
  import etc.c.zlib;
  import core.stdc.stdlib;

  enum IBSize = 65536;
  enum OBSize = 65536;

  lzma_stream zst;
  ubyte* ib, ob;
  int err;
  uint crc;
  uint prpsize;
  lzma_options_lzma lzmaopts;

  aborted = false;
  crc = crc32(0, null, 0);

  ib = cast(ubyte*)malloc(IBSize);
  if (ib is null) assert(0, "out of memory");
  scope(exit) free(ib);

  ob = cast(ubyte*)malloc(OBSize);
  if (ob is null) assert(0, "out of memory");
  scope(exit) free(ob);

  ulong srcsize = ss.size, outsize = 0;

  lzma_lzma_preset(&lzmaopts, 9|LZMA_PRESET_EXTREME);
  auto[2] filters = [lzma_filter(LZMA_FILTER_LZMA1, &lzmaopts), lzma_filter(LZMA_VLI_UNKNOWN)];
  if (lzma_properties_size(&prpsize, filters.ptr) != LZMA_OK) throw new Exception("LZMA error");
  if (prpsize != 5) throw new Exception("LZMA error");
  ubyte[5] props;
  if (lzma_properties_encode(filters.ptr, props.ptr) != LZMA_OK) throw new Exception("LZMA error");

  if (lzma_raw_encoder(&zst, filters.ptr) != LZMA_OK) throw new Exception("LZMA error");
  scope(exit) lzma_end(&zst);

  // zip lzma header
  ubyte[4] ziplzmahdr = 0;
  // lzma version
  ziplzmahdr[0] = 9;
  ziplzmahdr[1] = 15;
  ziplzmahdr[2] = cast(ubyte)prpsize;
  outsize += ziplzmahdr.length;
  ds.rawWriteExact(ziplzmahdr[]);

  // lzma properties
  outsize += prpsize;
  ds.rawWriteExact(props[]);

  zst.next_out = ob;
  zst.avail_out = OBSize;
  zst.next_in = ib;
  zst.avail_in = 0;

  ulong bytesread = 0;

  bool eof = false;
  while (!eof) {
    if (zst.avail_in == 0) {
      // read input buffer part
      auto rd = ss.rawRead(ib[0..IBSize]);
      eof = (rd.length == 0);
      if (rd.length != 0) { crc = crc32(crc, ib, cast(uint)rd.length); }
      zst.next_in = ib;
      zst.avail_in = cast(uint)rd.length;
      bytesread += rd.length;
      if (onProgress !is null) onProgress(bytesread);
    }
    // now process the whole input
    while (zst.avail_in > 0) {
      if (lzma_code(&zst, LZMA_RUN) != LZMA_OK) throw new Exception("LZMA error");
      if (zst.avail_out < OBSize) {
        if (outsize+(OBSize-zst.avail_out) >= srcsize) {
          // this will be overwritten anyway
          aborted = true;
          return 0;
        }
        outsize += OBSize-zst.avail_out;
        ds.rawWriteExact(ob[0..OBSize-zst.avail_out]);
        zst.next_out = ob;
        zst.avail_out = OBSize;
      }
    }
  }
  // empty write buffer
  for (;;) {
    zst.next_in = null;
    zst.avail_in = 0;
    auto res = lzma_code(&zst, LZMA_FINISH);
    if (res != LZMA_OK && res != LZMA_STREAM_END) throw new Exception("LZMA error");
    if (zst.avail_out < OBSize) {
      if (outsize+(OBSize-zst.avail_out) >= srcsize) {
        // this will be overwritten anyway
        aborted = true;
        return 0;
      }
      outsize += OBSize-zst.avail_out;
      ds.rawWriteExact(ob[0..OBSize-zst.avail_out]);
      zst.next_out = ob;
      zst.avail_out = OBSize;
    }
    if (res == LZMA_STREAM_END) break;
  }
  return crc;
}


// ////////////////////////////////////////////////////////////////////////// //
string toUtf8 (const(char)[] s) {
  import iv.utfutil;
  char[] res;
  char[4] buf;
  foreach (char ch; s) {
    auto len = utf8Encode(buf[], koi2uni(ch));
    if (len < 1) throw new Exception("invalid utf8");
    res ~= buf[0..len];
  }
  return cast(string)res; // safe cast
}


// ////////////////////////////////////////////////////////////////////////// //
// this will write "extra field length" and extra field itself
enum UtfFlags = (1<<10); // bit 11
//enum UtfFlags = 0;

ubyte[] buildUtfExtra (const(char)[] fname) {
  import etc.c.zlib : crc32;
  if (fname.length == 0) return null; // no need to write anything
  auto fu = toUtf8(fname);
  if (fu == fname) return null; // no need to write anything
  uint crc = crc32(0, cast(ubyte*)fname.ptr, cast(uint)fname.length);
  uint sz = 2+2+1+4+cast(uint)fu.length;
  auto res = new ubyte[](sz);
  res[0] = 'u';
  res[1] = 'p';
  sz -= 4;
  res[2] = sz&0xff;
  res[3] = (sz>>8)&0xff;
  res[4] = 1;
  res[5] = crc&0xff;
  res[6] = (crc>>8)&0xff;
  res[7] = (crc>>16)&0xff;
  res[8] = (crc>>24)&0xff;
  res[9..$] = cast(const(ubyte)[])fu[];
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
// returns `nfoofs`
long zipWriteLocalHeader() (VFile ds, in auto ref ZipFileInfo res) {
  static immutable char[4] sign = "PK\x03\x04";
  auto ef = buildUtfExtra(res.name);
  if (ef.length > ushort.max) throw new Exception("extra field too big");
  if (res.size > uint.max-1) throw new Exception("file too big");
  ds.rawWriteExact(sign[]);
  //ds.writeNum!ushort(0x0310); // version to extract
  ds.writeNum!ushort(res.method > 8 ? 0x003f : 0x0014); // version to extract
  ds.writeNum!ushort(ef.length ? UtfFlags : 0); // flags
  ds.writeNum!ushort(res.method); // compression method
  ds.writeNum!ushort(res.time.mtime); // file time
  ds.writeNum!ushort(res.time.mdate); // file date
  auto nfoofs = ds.tell;
  ds.writeNum!uint(res.crc); // crc32
  ds.writeNum!uint(res.method ? 0 : cast(uint)res.size); // packed size
  ds.writeNum!uint(cast(uint)res.size); // unpacked size
  ds.writeNum!ushort(cast(ushort)res.name.length); // name length
  ds.writeNum!ushort(cast(ushort)ef.length); // extra field length
  ds.rawWriteExact(res.name[]);
  if (ef.length > 0) ds.rawWriteExact(ef[]);
  return nfoofs;
}


void zipWriteCentralHeader() (VFile ds, in auto ref ZipFileInfo fi) {
  static immutable char[4] sign = "PK\x01\x02";
  auto ef = buildUtfExtra(fi.name);
  ds.rawWriteExact(sign[]);
  ds.writeNum!ushort(0x0310); // version made by
  ds.writeNum!ushort(fi.method > 8 ? 0x003f : 0x0014); // version to extract
  ds.writeNum!ushort(ef.length ? UtfFlags : 0); // flags
  ds.writeNum!ushort(fi.method); // compression method
  ds.writeNum!ushort(fi.time.mtime); // file time
  ds.writeNum!ushort(fi.time.mdate); // file date
  ds.writeNum!uint(fi.crc);
  ds.writeNum!uint(cast(uint)fi.pksize);
  ds.writeNum!uint(cast(uint)fi.size);
  ds.writeNum!ushort(cast(ushort)fi.name.length); // name length
  ds.writeNum!ushort(cast(ushort)ef.length); // extra field length
  ds.writeNum!ushort(0); // comment length
  ds.writeNum!ushort(0); // disk start
  ds.writeNum!ushort(0); // internal attributes
  // external attributes
  ushort umode = fi.unixmode;
  if (umode == 0) umode = (fi.dir ? fi.DefaultMode.Dir : fi.DefaultMode.File);
  uint mode;
  if (fi.dir) {
    //ds.writeNum!uint(0b0_100_000_111_101_101_0000000000_000010);
    ds.writeNum!uint(0b0_100_000_000_000_000_0000000000_000010|(umode<<16));
  } else {
    // regular file
    //ds.writeNum!uint(0b1_000_000_110_100_000_0000000000_000000);
    ds.writeNum!uint(0b1_000_000_110_100_000_0000000000_000000|(umode<<16));
  }
  ds.writeNum!uint(cast(uint)fi.pkofs); // header offset
  ds.rawWriteExact(fi.name[]);
  if (ef.length > 0) ds.rawWriteExact(ef[]);
}


// ////////////////////////////////////////////////////////////////////////// //
ZipFileInfo zipOne(string mtname="deflate") (VFile ds, const(char)[] fname, VFile st, ulong oldsize=ulong.max, scope void delegate (ulong cur) onProgress=null) {
  return zipOne!mtname(ds, fname, st, ZipFileTime.init, oldsize, onProgress);
}

ZipFileInfo zipOne(string mtname="deflate") (VFile ds, const(char)[] fname, VFile st, in auto ref ZipFileTime ftime, ulong oldsize=ulong.max, scope void delegate (ulong cur) onProgress=null) {
  static assert(mtname == "store" || mtname == "deflate" || mtname == "lzma", "invalid method: '"~mtname~"'");
  ZipFileInfo res;

  if (fname.length == 0 || fname.length > ushort.max) throw new Exception("inalid file name");

  res.time = ftime;
  res.pkofs = ds.tell;
  res.size = st.size;
  static if (mtname == "store") {
    res.method = 0;
  } else static if (mtname == "deflate") {
    res.method = (res.size > 0 ? 8 : 0);
  } else static if (mtname == "lzma") {
    static if (VFSZipWriterSupportsLZMA) {
      res.method = (res.size > 0 ? 14 : 0);
    } else {
      static assert(0, "LZMA method is not supported");
    }
  } else {
    static assert(0, "wtf?!");
  }
  bool dopack = (res.method != 0);
  if (!dopack) { res.method = 0; res.pksize = res.size; }
  res.name = fname.idup;

  auto nfoofs = ds.zipWriteLocalHeader(res);
  if (dopack) {
    // write packed data
    if (res.size > 0) {
      bool aborted;
      auto pkdpos = ds.tell;
      st.seek(0);
      static if (mtname == "deflate") {
        res.crc = zpack(ds, st, aborted, onProgress);
      } else static if (mtname == "lzma") {
        res.crc = lzmapack(ds, st, aborted, onProgress);
      } else static if (mtname == "store") {
        assert(0, "wtf?!");
      } else {
        static assert(0, "wtf?!");
      }
      res.pksize = ds.tell-pkdpos;
      if (aborted) {
        // there's no sense to pack this file
        static if (mtname == "lzma") {
          // try deflate, it may work
          st.seek(0);
          ds.seek(res.pkofs);
          return zipOne!"deflate"(ds, fname, st, ftime, oldsize, onProgress);
        } else {
          // just store it
          st.seek(0);
          ds.seek(res.pkofs);
          return zipOne!"store"(ds, fname, st, ftime, oldsize, onProgress);
        }
      } else if (res.pksize == oldsize) {
        //{ import core.stdc.stdio : printf; printf("  size=%u; pksize=%u; oldsize=%u\n", cast(uint)res.size, cast(uint)res.pksize, cast(uint)oldsize); }
        // if file got the same size, just store it
        st.seek(0);
        ds.seek(res.pkofs);
        return zipOne!"store"(ds, fname, st, ftime, oldsize, onProgress);
      }
    }
  } else {
    import etc.c.zlib : crc32;
    import core.stdc.stdlib;
    enum bufsz = 65536;
    auto buf = cast(ubyte*)malloc(bufsz);
    if (buf is null) assert(0, "out of memory");
    scope(exit) free(buf);
    st.seek(0);
    res.crc = crc32(0, null, 0);
    res.pksize = 0;
    ulong bytesread = 0;
    while (res.pksize < res.size) {
      auto rd = res.size-res.pksize;
      if (rd > bufsz) rd = bufsz;
      st.rawReadExact(buf[0..cast(uint)rd]);
      bytesread += rd;
      if (onProgress !is null) onProgress(bytesread);
      ds.rawWriteExact(buf[0..cast(uint)rd]);
      res.pksize += rd;
      res.crc = crc32(res.crc, buf, cast(uint)rd);
    }
  }
  // fix header
  auto oldofs = ds.tell;
  scope(exit) ds.seek(oldofs);
  ds.seek(nfoofs);
  ds.writeNum!uint(res.crc); // crc32
  if (dopack) ds.writeNum!uint(cast(uint)res.pksize);
  return res;
}


// ////////////////////////////////////////////////////////////////////////// //
void zipFinish (VFile ds, const(ZipFileInfo)[] files) {
  if (files.length > ushort.max) throw new Exception("too many files");
  static immutable char[4] sign = "PK\x05\x06";
  auto cdofs = ds.tell;
  foreach (const ref fi; files) ds.zipWriteCentralHeader(fi);
  auto cdend = ds.tell;
  // write end of central dir
  ds.rawWriteExact(sign[]);
  ds.writeNum!ushort(0); // disk number
  ds.writeNum!ushort(0); // disk with central dir
  ds.writeNum!ushort(cast(ushort)files.length); // number of files on this dist
  ds.writeNum!ushort(cast(ushort)files.length); // number of files total
  ds.writeNum!uint(cast(uint)(cdend-cdofs)); // size of central directory
  ds.writeNum!uint(cast(uint)cdofs); // central directory offset
  ds.writeNum!ushort(0); // archive comment length
}
